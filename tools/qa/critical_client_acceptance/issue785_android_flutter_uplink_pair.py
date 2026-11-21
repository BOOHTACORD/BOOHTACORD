"""Run a paired Android Flutter microphone uplink background/resume check."""

import argparse
import base64
import hashlib
import json
import os
import re
import shutil
import socket
import ssl
import subprocess
import tempfile
import time
from pathlib import Path

from tools.qa.critical_client_acceptance.stack import Stack
from tools.qa.local_features.android_microphone import android_microphone_permission
from tools.qa.local_features.native import verify_device

PACKAGE = 'ru.boohtacord.app'
CONTROL = 'issue785_flutter_uplink_control.json'
ORIGIN = 'https://localhost:4810/api/v1'
MIN_BACKGROUND_SECONDS = 120
DEFAULT_BACKGROUND_SECONDS = 120
BLACKHOLE_OFFSET_SECONDS = 5
BLACKHOLE_RECOVERY_SECONDS = 15
BLACKHOLE_RULES = (
    ('-d', '127.0.0.1/32', '-p', 'tcp', '-m', 'multiport', '--dports', '4810,4881', '-j', 'DROP'),
    ('-d', '127.0.0.1/32', '-p', 'udp', '--dport', '4882', '-j', 'DROP'),
)


def validate_background_seconds(seconds):
    if seconds < MIN_BACKGROUND_SECONDS:
        raise ValueError('Issue 785 Android microphone reproduction must be at least 120 seconds')
    return seconds


def validate_blackhole_seconds(background_seconds, blackhole_seconds):
    if blackhole_seconds < 0:
        raise ValueError('Network blackhole duration cannot be negative')
    if blackhole_seconds and blackhole_seconds + BLACKHOLE_OFFSET_SECONDS >= background_seconds:
        raise ValueError('Network blackhole must leave time for post-outage recovery')
    return blackhole_seconds


def display_is_asleep(power_dump):
    return bool(re.search(r'(?mi)^\s*mWakefulness=Asleep\s*$', power_dump))


def receiver_progressed_during_background(samples, start_unix_ms, end_unix_ms):
    interval = [
        sample for sample in samples
        if start_unix_ms <= sample.get('observed_at_unix_ms', -1) <= end_unix_ms
    ]
    if len(interval) < 2:
        return False
    first, last = interval[0], interval[-1]
    return (
        last.get('inbound_audio_packets', 0) > first.get('inbound_audio_packets', 0)
        and last.get('inbound_audio_bytes', 0) > first.get('inbound_audio_bytes', 0)
    )


def receiver_has_foreground_uplink(sample):
    return bool(
        sample
        and sample.get('inbound_audio_tracks', 0) > 0
        and sample.get('inbound_audio_packets', 0) > 0
        and sample.get('inbound_audio_bytes', 0) > 0
    )


def receiver_blackhole_recovery(samples, started_unix_ms, ended_unix_ms, recovery_seconds=BLACKHOLE_RECOVERY_SECONDS):
    before = [
        sample for sample in samples
        if sample.get('observed_at_unix_ms', -1) < started_unix_ms
        and receiver_has_foreground_uplink(sample)
    ]
    during = [
        sample for sample in samples
        if started_unix_ms <= sample.get('observed_at_unix_ms', -1) <= ended_unix_ms
    ]
    after = [
        sample for sample in samples
        if ended_unix_ms < sample.get('observed_at_unix_ms', -1) <= ended_unix_ms + recovery_seconds * 1000
        and receiver_has_foreground_uplink(sample)
    ]
    if not before or len(during) < 2 or not after:
        return None
    first_during, last_during = during[0], during[-1]
    paused = (
        last_during.get('inbound_audio_tracks', 0) == 0
        or last_during.get('inbound_audio_packets', 0) <= first_during.get('inbound_audio_packets', 0)
        or last_during.get('inbound_audio_bytes', 0) <= first_during.get('inbound_audio_bytes', 0)
    )
    if not paused:
        return None
    recovered = after[0]
    return {
        'receiver_before_blackhole': before[-1],
        'receiver_last_during_blackhole': last_during,
        'receiver_after_recovery': recovered,
        'recovery_seconds': round((recovered['observed_at_unix_ms'] - ended_unix_ms) / 1000, 3),
    }


def parse_blackhole_drop_counters(output):
    counters = {
        'udp_4882': {'packets': 0, 'bytes': 0},
        'tcp_4810_4881': {'packets': 0, 'bytes': 0},
    }
    for line in output.splitlines():
        match = re.match(r'^\s*(\d+)\s+(\d+)\s+DROP\b', line)
        if not match:
            continue
        if 'udp dpt:4882' in line:
            key = 'udp_4882'
        elif 'multiport dports 4810,4881' in line:
            key = 'tcp_4810_4881'
        else:
            continue
        counters[key] = {'packets': int(match.group(1)), 'bytes': int(match.group(2))}
    return counters


def install_blackhole(device):
    if not device.startswith('emulator-'):
        raise ValueError('Android network blackhole injection is restricted to AVD emulators')
    if adb(device, 'shell', 'id', '-u').stdout.strip() != '0':
        raise RuntimeError('Android emulator needs root adb for app server/media blackhole injection')
    installed = []
    try:
        for rule in BLACKHOLE_RULES:
            if adb(device, 'shell', 'iptables', '-C', 'OUTPUT', *rule, check=False).returncode == 0:
                raise RuntimeError('A matching Android emulator blackhole firewall rule already exists')
            adb(device, 'shell', 'iptables', '-I', 'OUTPUT', '1', *rule)
            installed.append(rule)
    except Exception:
        remove_blackhole(device, installed)
        raise
    return installed


def remove_blackhole(device, rules):
    if not rules:
        return {'udp_4882': {'packets': 0, 'bytes': 0}, 'tcp_4810_4881': {'packets': 0, 'bytes': 0}}
    output = adb(device, 'shell', 'iptables', '-L', 'OUTPUT', '-v', '-n', '-x').stdout
    counters = parse_blackhole_drop_counters(output)
    failures = []
    for rule in reversed(rules):
        result = adb(device, 'shell', 'iptables', '-D', 'OUTPUT', *rule, check=False)
        if result.returncode:
            failures.append(result.stderr.strip() or 'iptables rule removal failed')
    if failures:
        raise RuntimeError('; '.join(failures))
    return counters


def adb(device, *args, check=True):
    return subprocess.run(
        ['adb', '-s', device, *args],
        check=check,
        capture_output=True,
        text=True,
    )


def wait_for_display(device, *, asleep, timeout=20):
    deadline = time.monotonic() + timeout
    last = ''
    while time.monotonic() < deadline:
        last = adb(device, 'shell', 'dumpsys', 'power').stdout
        if display_is_asleep(last) == asleep:
            return last
        time.sleep(.25)
    expected = 'asleep' if asleep else 'awake'
    raise TimeoutError(f'Android display did not become {expected}')


def wake_display(device):
    power_dump = adb(device, 'shell', 'dumpsys', 'power', check=False).stdout
    if display_is_asleep(power_dump):
        adb(device, 'shell', 'input', 'keyevent', '26', check=False)
        wait_for_display(device, asleep=False)
    adb(device, 'shell', 'wm', 'dismiss-keyguard', check=False)


def control_json(device):
    result = adb(device, 'shell', 'run-as', PACKAGE, 'cat', f'cache/{CONTROL}', check=False)
    if result.returncode:
        return None
    try:
        return json.loads(result.stdout)
    except json.JSONDecodeError as error:
        raise RuntimeError('Android QA control file was not valid JSON') from error


def set_control(device, status, **metadata):
    payload = {'status': status, **metadata}
    encoded = base64.b64encode(json.dumps(payload).encode()).decode()
    command = (
        f"run-as {PACKAGE} sh -c 'printf %s {encoded} | base64 -d > "
        f"cache/{CONTROL}.tmp && mv cache/{CONTROL}.tmp cache/{CONTROL}'"
    )
    adb(device, 'shell', command)


def top_activity(device):
    return adb(device, 'shell', 'dumpsys', 'activity', 'activities').stdout


def wait_activity(device, pattern, timeout=30):
    deadline = time.monotonic() + timeout
    last = ''
    while time.monotonic() < deadline:
        last = top_activity(device)
        if pattern.search(last):
            return last
        time.sleep(.5)
    raise RuntimeError(f'Android activity did not reach expected state: {pattern.pattern}')


def tail(path, secret='', limit=6000):
    try:
        output = path.read_text(encoding='utf8', errors='replace')[-limit:]
    except FileNotFoundError:
        return ''
    return output.replace(secret, '[redacted]') if secret else output


def microphone_foreground_service_active(service_dump):
    return bool(re.search(r'(?i)(?:Microphone|VoiceMicrophone).*Service', service_dump))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--device', required=True)
    parser.add_argument('--background-seconds', type=int, default=DEFAULT_BACKGROUND_SECONDS)
    parser.add_argument('--background-action', choices=('home', 'screen-off'), default='home')
    parser.add_argument('--blackhole-seconds', type=int, default=0)
    parser.add_argument('--output', required=True)
    args = parser.parse_args()
    validate_background_seconds(args.background_seconds)
    validate_blackhole_seconds(args.background_seconds, args.blackhole_seconds)

    root = Path(__file__).resolve().parents[3]
    device = args.device
    output = Path(args.output).resolve()
    if output.exists() and any(output.iterdir()):
        raise FileExistsError(f'QA output directory is not empty: {output}')
    output.mkdir(parents=True, exist_ok=True)
    verify_device('android', device)
    if adb(device, 'shell', 'getprop', 'sys.boot_completed').stdout.strip() != '1':
        raise RuntimeError('Android QA emulator is not fully booted')
    if any(f'tcp:{port}' in adb(device, 'reverse', '--list').stdout.split() for port in (4810, 4881)):
        raise ValueError('An existing QA reverse belongs to another run')
    if args.blackhole_seconds:
        if not device.startswith('emulator-'):
            raise ValueError('The app-scoped network blackhole can run only on an Android emulator')
        adb(device, 'root')
        adb(device, 'wait-for-device')
        if adb(device, 'shell', 'id', '-u').stdout.strip() != '0':
            raise RuntimeError('Android emulator does not provide root adb for network blackhole injection')
        if adb(device, 'shell', 'getprop', 'sys.boot_completed').stdout.strip() != '1':
            raise RuntimeError('Android QA emulator did not finish booting after enabling root adb')
        if any(f'tcp:{port}' in adb(device, 'reverse', '--list').stdout.split() for port in (4810, 4881)):
            raise ValueError('An existing QA reverse belongs to another run')
    if control_json(device) is not None:
        raise FileExistsError('A stale Android pair QA control file exists')

    root_out = root / '.out'
    root_out.mkdir(exist_ok=True)
    work = Path(tempfile.mkdtemp(prefix='issue785-flutter-uplink-', dir=root_out))
    stack = Stack(root, work)
    created_reverse = []
    receiver = None
    flutter = None
    input_path = work / 'pair-input.json'
    ready_path = work / 'pair-ready.json'
    final_path = work / 'pair-final.json'
    progress_path = work / 'pair-progress.json'
    receiver_log = work / 'receiver.log'
    flutter_log = work / 'flutter-drive.log'
    result_file = None
    background_started_unix_ms = 0
    background_ended_unix_ms = 0
    microphone_samples = []
    active_blackhole_rules = []
    network_outage = None
    try:
        os.environ.update({
            'DOCKER_CONTEXT': 'colima-boohtacord-qa',
            'BOOHTACORD_QA_EGRESS_PLATFORM': 'linux/amd64',
            'VITE_PUBLIC_ORIGIN': ORIGIN.removesuffix('/api/v1'),
            'QA_ORIGIN': ORIGIN.removesuffix('/api/v1'),
            'QA_DB_OWNER': stack.owner,
        })
        for port in (4810, 4881):
            adb(device, 'reverse', f'tcp:{port}', f'tcp:{port}')
            created_reverse.append(port)

        stack.start()
        context = ssl._create_unverified_context()
        with socket.create_connection(('127.0.0.1', 4810), timeout=5) as plain:
            with context.wrap_socket(plain, server_hostname='localhost') as secure:
                pin = hashlib.sha256(secure.getpeercert(binary_form=True)).hexdigest()

        input_path.write_text(json.dumps({
            'origin': ORIGIN.removesuffix('/api/v1'),
            'password': stack.password,
        }), encoding='utf8')
        input_path.chmod(0o600)
        receiver_env = dict(
            os.environ,
            QA_PAIR_INPUT=str(input_path),
            QA_PAIR_READY=str(ready_path),
            QA_PAIR_FINAL=str(final_path),
            QA_PAIR_PROGRESS=str(progress_path),
        )
        with receiver_log.open('w', encoding='utf8') as receiver_output:
            receiver = subprocess.Popen(
                ['node', 'tools/qa/critical_client_acceptance/issue785_flutter_uplink_receiver.mjs'],
                cwd=root,
                env=receiver_env,
                stdin=subprocess.PIPE,
                stdout=receiver_output,
                stderr=subprocess.STDOUT,
                text=True,
            )
            deadline = time.monotonic() + 120
            while not ready_path.exists() and time.monotonic() < deadline:
                if receiver.poll() is not None:
                    raise RuntimeError(f'Paired receiver failed:\n{tail(receiver_log, stack.password)}')
                time.sleep(.5)
            if not ready_path.exists():
                raise TimeoutError(f'Paired receiver did not become ready:\n{tail(receiver_log, stack.password)}')
            pair = json.loads(ready_path.read_text(encoding='utf8'))

            defines = work / 'defines.json'
            defines.write_text(json.dumps({
                'QA_API_BASE': ORIGIN,
                'QA_CERT_SHA256': pin,
                'QA_PASSWORD': stack.password,
                'QA_PAIR_CHANNEL_ID': pair['channelId'],
            }), encoding='utf8')
            defines.chmod(0o600)
            capture_dir = output / 'screenshots'
            capture_dir.mkdir(exist_ok=True)
            flutter_env = dict(os.environ, BOOHTACORD_NATIVE_CAPTURE_DIR=str(capture_dir))
            flutter_args = [
                'flutter', 'drive', '--driver', 'test_driver/local_qa.dart',
                '--target', 'integration_test/issue785_background_microphone_uplink_test.dart',
                '-d', device, '--dart-define-from-file', str(defines),
            ]
            with flutter_log.open('w', encoding='utf8') as flutter_output:
                with android_microphone_permission(
                    'android', device,
                    'integration_test/issue785_background_microphone_uplink_test.dart',
                ):
                    flutter = subprocess.Popen(
                        flutter_args,
                        cwd=root / 'clients/flutter',
                        env=flutter_env,
                        stdout=flutter_output,
                        stderr=subprocess.STDOUT,
                        text=True,
                    )
                    ready_deadline = time.monotonic() + 1200
                    while time.monotonic() < ready_deadline:
                        command = control_json(device)
                        if command and command.get('status') == 'ready':
                            break
                        if flutter.poll() is not None:
                            raise RuntimeError(f'Flutter publisher did not become ready:\n{tail(flutter_log, stack.password)}')
                        time.sleep(1)
                    else:
                        raise TimeoutError(f'Flutter publisher did not reach paired audio baseline:\n{tail(flutter_log, stack.password)}')

                    receiver_deadline = time.monotonic() + 30
                    foreground_receiver = None
                    while time.monotonic() < receiver_deadline:
                        if progress_path.exists():
                            foreground_receiver = json.loads(progress_path.read_text(encoding='utf8'))
                            if receiver_has_foreground_uplink(foreground_receiver):
                                break
                        if flutter.poll() is not None:
                            raise RuntimeError(f'Flutter publisher exited before Android backgrounding:\n{tail(flutter_log, stack.password)}')
                        if receiver.poll() is not None:
                            raise RuntimeError(f'Paired receiver exited before Android backgrounding:\n{tail(receiver_log, stack.password)}')
                        time.sleep(.5)
                    if not receiver_has_foreground_uplink(foreground_receiver):
                        raise RuntimeError(
                            'Foreground pair precondition failed: independent receiver saw no inbound audio RTP before Android backgrounding; '
                            f'latest counters={foreground_receiver!r}'
                        )
                    print(
                        'Foreground paired audio confirmed before Android Home: '
                        f"{foreground_receiver['inbound_audio_packets']} packets / "
                        f"{foreground_receiver['inbound_audio_bytes']} bytes",
                        flush=True,
                    )

                    services = adb(device, 'shell', 'dumpsys', 'activity', 'services', PACKAGE).stdout
                    active = microphone_foreground_service_active(services)
                    if not active:
                        raise RuntimeError('Mic-enabled Flutter session did not start its microphone foreground service')
                    if args.background_action == 'home':
                        adb(device, 'shell', 'input', 'keyevent', '3')
                        launcher = wait_activity(device, re.compile(r'topResumedActivity=.*(?:nexuslauncher|Launcher)', re.I))
                        initial_screen_state = adb(device, 'shell', 'dumpsys', 'power').stdout
                        if display_is_asleep(initial_screen_state):
                            raise RuntimeError('Android Home unexpectedly turned the display off')
                    else:
                        adb(device, 'shell', 'input', 'keyevent', '26')
                        initial_screen_state = wait_for_display(device, asleep=True)
                        launcher = None
                    background_started = time.monotonic()
                    background_started_unix_ms = int(time.time() * 1000)
                    microphone_samples = [{
                        'offset_seconds': 0.0,
                        'microphone_foreground_service_active': active,
                        'display_asleep': display_is_asleep(initial_screen_state),
                    }]
                    next_sample = 30
                    print(f'Android {args.background_action} observed; microphone background target: {args.background_seconds}s', flush=True)
                    while time.monotonic() - background_started < args.background_seconds:
                        if flutter.poll() is not None:
                            raise RuntimeError(f'Flutter integration exited while backgrounded:\n{tail(flutter_log, stack.password)}')
                        elapsed = time.monotonic() - background_started
                        if args.blackhole_seconds and network_outage is None and elapsed >= BLACKHOLE_OFFSET_SECONDS:
                            active_blackhole_rules = install_blackhole(device)
                            outage_started_unix_ms = int(time.time() * 1000)
                            outage_started = time.monotonic()
                            outage_service_samples = []
                            next_outage_sample = outage_started
                            print(
                                f'Endpoint-scoped API/LiveKit blackhole active for {args.blackhole_seconds}s',
                                flush=True,
                            )
                            outage_deadline = outage_started + args.blackhole_seconds
                            while time.monotonic() < outage_deadline:
                                if flutter.poll() is not None:
                                    raise RuntimeError(
                                        f'Flutter integration exited during network blackhole:\n{tail(flutter_log, stack.password)}'
                                    )
                                if time.monotonic() >= next_outage_sample:
                                    outage_services = adb(
                                        device,
                                        'shell',
                                        'dumpsys',
                                        'activity',
                                        'services',
                                        PACKAGE,
                                    ).stdout
                                    service_active = microphone_foreground_service_active(outage_services)
                                    outage_service_samples.append({
                                        'offset_seconds': round(time.monotonic() - outage_started, 3),
                                        'microphone_foreground_service_active': service_active,
                                    })
                                    if not service_active:
                                        raise RuntimeError('Microphone FGS stopped during the Android network blackhole')
                                    next_outage_sample += 5
                                time.sleep(min(1, max(0.0, outage_deadline - time.monotonic())))
                            drop_counters = remove_blackhole(device, active_blackhole_rules)
                            active_blackhole_rules = []
                            outage_ended_unix_ms = int(time.time() * 1000)
                            dropped_packets = sum(value['packets'] for value in drop_counters.values())
                            if dropped_packets <= 0:
                                raise RuntimeError('Android firewall did not record dropped API/LiveKit packets')
                            network_outage = {
                                'kind': 'endpoint-scoped Android loopback API/LiveKit blackhole',
                                'blocked_endpoints': [
                                    'TCP 127.0.0.1:4810,4881',
                                    'UDP 127.0.0.1:4882',
                                ],
                                'duration_seconds_requested': args.blackhole_seconds,
                                'started_at_unix_ms': outage_started_unix_ms,
                                'ended_at_unix_ms': outage_ended_unix_ms,
                                'duration_seconds_observed': round(
                                    (outage_ended_unix_ms - outage_started_unix_ms) / 1000,
                                    3,
                                ),
                                'firewall_drop_counters': drop_counters,
                                'microphone_foreground_service_samples': outage_service_samples,
                            }
                            print(
                                'Endpoint-scoped API/LiveKit blackhole removed; dropped packets='
                                f'{dropped_packets}',
                                flush=True,
                            )
                            continue
                        if elapsed >= next_sample:
                            services = adb(device, 'shell', 'dumpsys', 'activity', 'services', PACKAGE).stdout
                            active = microphone_foreground_service_active(services)
                            screen_state = adb(device, 'shell', 'dumpsys', 'power').stdout
                            asleep = display_is_asleep(screen_state)
                            microphone_samples.append({
                                'offset_seconds': round(elapsed, 3),
                                'microphone_foreground_service_active': active,
                                'display_asleep': asleep,
                            })
                            if not active:
                                raise RuntimeError(f'Microphone foreground service stopped during Android {args.background_action}')
                            if args.background_action == 'screen-off' and not asleep:
                                raise RuntimeError('Android display woke during the screen-off background interval')
                            next_sample += 30
                        time.sleep(min(1, max(0.0, args.background_seconds - elapsed)))
                    observed_background = time.monotonic() - background_started
                    background_ended_unix_ms = int(time.time() * 1000)
                    services = adb(device, 'shell', 'dumpsys', 'activity', 'services', PACKAGE).stdout
                    active = microphone_foreground_service_active(services)
                    final_screen_state = adb(device, 'shell', 'dumpsys', 'power').stdout
                    final_display_asleep = display_is_asleep(final_screen_state)
                    microphone_samples.append({
                        'offset_seconds': round(observed_background, 3),
                        'microphone_foreground_service_active': active,
                        'display_asleep': final_display_asleep,
                    })
                    if not active:
                        raise RuntimeError(f'Microphone foreground service was not active at the end of Android {args.background_action}')
                    if args.background_action == 'screen-off' and not final_display_asleep:
                        raise RuntimeError('Android display was awake at the end of the screen-off background interval')
                    set_control(
                        device,
                        'resume',
                        backgroundSecondsObserved=round(observed_background, 3),
                        backgroundStartedUnixMs=background_started_unix_ms,
                        backgroundEndedUnixMs=background_ended_unix_ms,
                        microphoneServiceSamples=microphone_samples,
                    )
                    if args.background_action == 'screen-off':
                        adb(device, 'shell', 'input', 'keyevent', '26')
                        wait_for_display(device, asleep=False)
                        adb(device, 'shell', 'wm', 'dismiss-keyguard', check=False)
                    adb(device, 'shell', 'am', 'start', '-n', f'{PACKAGE}/.MainActivity')
                    wait_activity(device, re.compile(r'topResumedActivity=.*ru\.boohtacord\.app', re.I))
                    result_deadline = time.monotonic() + 120
                    while time.monotonic() < result_deadline:
                        result_file = control_json(device)
                        if result_file and result_file.get('status') == 'complete':
                            (output / 'flutter-result.json').write_text(
                                json.dumps(result_file, indent=2) + '\n', encoding='utf8',
                            )
                            set_control(device, 'acknowledged')
                            break
                        if flutter.poll() is not None:
                            raise RuntimeError(f'Flutter integration exited before reporting results:\n{tail(flutter_log, stack.password)}')
                        time.sleep(.25)
                    if not result_file or result_file.get('status') != 'complete':
                        raise TimeoutError(f'Flutter integration did not report after resume:\n{tail(flutter_log, stack.password)}')
                    try:
                        exit_code = flutter.wait(timeout=240)
                    except subprocess.TimeoutExpired as error:
                        raise TimeoutError(f'Flutter pair test did not finish after resume:\n{tail(flutter_log, stack.password)}') from error
                    if exit_code != 0:
                        raise RuntimeError(f'Flutter pair test failed:\n{tail(flutter_log, stack.password)}')

        if receiver is not None and receiver.poll() is None:
            receiver.stdin.write('STOP\n')
            receiver.stdin.flush()
            final_deadline = time.monotonic() + 10
            while not final_path.exists() and time.monotonic() < final_deadline:
                if receiver.poll() is not None:
                    break
                time.sleep(.1)
            if final_path.exists():
                shutil.copy2(final_path, output / 'receiver-result.json')
            try:
                receiver.wait(timeout=30)
            except subprocess.TimeoutExpired as error:
                raise TimeoutError(f'Paired receiver did not stop cleanly:\n{tail(receiver_log, stack.password)}') from error
        if receiver is None or receiver.returncode != 0 or not final_path.exists():
            raise RuntimeError(f'Paired receiver did not save final counters:\n{tail(receiver_log, stack.password)}')
        receiver_result = json.loads(final_path.read_text(encoding='utf8'))
        samples = receiver_result.get('samples', [])
        if not receiver_progressed_during_background(
            samples,
            background_started_unix_ms,
            background_ended_unix_ms,
        ):
            raise RuntimeError('Independent receiver RTP counters did not advance inside the Flutter background interval')
        if network_outage is not None:
            if any(
                network_outage['firewall_drop_counters'][key]['packets'] <= 0
                for key in ('udp_4882', 'tcp_4810_4881')
            ):
                raise RuntimeError('Android firewall did not record drops for both LiveKit media and app API signaling')
            recovery = receiver_blackhole_recovery(
                samples,
                network_outage['started_at_unix_ms'],
                network_outage['ended_at_unix_ms'],
            )
            if recovery is None:
                raise RuntimeError('Independent receiver did not show a media pause and recovery within 15 seconds of network restore')
            network_outage.update(recovery)
        if len(microphone_samples) < 5 or not all(
            sample['microphone_foreground_service_active'] for sample in microphone_samples
        ):
            raise RuntimeError('Microphone FGS continuity was not observed across the full background interval')

        adb(device, 'shell', 'run-as', PACKAGE, 'rm', '-f', f'cache/{CONTROL}', check=False)
        post_leave = adb(device, 'shell', 'dumpsys', 'activity', 'services', PACKAGE, check=False).stdout
        cleanup = not microphone_foreground_service_active(post_leave)
        result = {
            'status': 'PASS_SCOPED',
            'issue': 785,
            'source': {
                'working_tree_head': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=root, text=True).strip(),
                'working_tree_clean_product_source': True,
            },
            'environment': {
                'runtime': 'Android 15 / API 35 AOSP ARM64 emulator',
                'avd': 'BOOHTACORD_QA_API35',
                'device': device,
                'physical_device': False,
                'publisher': 'Flutter Android microphone foreground service',
                'receiver': 'Playwright Chromium listener-only participant',
                'server': 'Owned disposable API/PostgreSQL/LiveKit QA stack',
            },
            'scenario': {
                'background_action': 'Android Home' if args.background_action == 'home' else 'Android screen off (secure keyguard not asserted)',
                'home_activity_observed': bool(launcher),
                'screen_off_observed': args.background_action == 'screen-off' and all(
                    sample['display_asleep'] for sample in microphone_samples
                ),
                'secure_keyguard': 'NOT_VERIFIED',
                'background_seconds_requested': args.background_seconds,
                'background_seconds_observed': round(observed_background, 3),
                'microphone_foreground_service_samples': microphone_samples,
                'microphone_service_stopped_after_leave': cleanup,
                'voice_phase_after_resume': result_file['result']['voicePhase'],
                'same_room_after_resume': result_file['result']['sameRoomObjectAfterResume'],
                'network_outage': network_outage,
            },
            'receiver_media': receiver_result,
            'publisher_media': result_file['result'],
            'media_result': 'PASS_SCOPED: independent receiver inbound RTP packets and bytes advanced during the measured background interval; emulator audio level and acoustic output were not measured',
            'limitations': [
                'RTP counters prove transport delivery, not microphone intelligibility or audible output.',
                'The emulator microphone input may be silent; no acoustic loopback or independent human listening was used.',
                'This is a 120-second AOSP emulator run, not physical Android acceptance.',
                'Issue 785 release gate remains open.',
            ] + (
                ['The endpoint-scoped loopback blackhole does not simulate a physical Wi-Fi/LTE interface transition.']
                if network_outage is not None else
                ['Secure keyguard, network transitions, airplane mode, OS-forced service stop, iOS, Safari/PWA, release APK, and production smoke remain unverified.']
            ),
        }
        (output / 'receiver-result.json').write_text(json.dumps(receiver_result, indent=2) + '\n', encoding='utf8')
        (output / 'result.json').write_text(json.dumps(result, indent=2) + '\n', encoding='utf8')
        shutil.copy2(flutter_log, output / 'flutter-drive.log')
        shutil.copy2(receiver_log, output / 'receiver.log')
        print('RESULT=' + json.dumps(result), flush=True)
    except Exception:
        if final_path.exists():
            shutil.copy2(final_path, output / 'receiver-result.json')
        if flutter_log.exists():
            shutil.copy2(flutter_log, output / 'flutter-drive.log')
        if receiver_log.exists():
            shutil.copy2(receiver_log, output / 'receiver.log')
        raise
    finally:
        try:
            if flutter is not None and flutter.poll() is None:
                flutter.terminate()
                try:
                    flutter.wait(timeout=10)
                except subprocess.TimeoutExpired:
                    flutter.kill()
            if receiver is not None and receiver.poll() is None:
                try:
                    receiver.stdin.write('STOP\n')
                    receiver.stdin.flush()
                    receiver.wait(timeout=15)
                except (BrokenPipeError, subprocess.TimeoutExpired):
                    receiver.terminate()
            if receiver is not None and receiver.returncode not in (None, 0):
                print(f'Receiver log:\n{tail(receiver_log, stack.password)}')
        finally:
            try:
                if active_blackhole_rules:
                    remove_blackhole(device, active_blackhole_rules)
                    active_blackhole_rules = []
                if args.background_action == 'screen-off':
                    wake_display(device)
                stack.close()
            finally:
                adb(device, 'shell', 'run-as', PACKAGE, 'rm', '-f', f'cache/{CONTROL}', check=False)
                for port in reversed(created_reverse):
                    adb(device, 'reverse', '--remove', f'tcp:{port}', check=False)
                shutil.rmtree(work, ignore_errors=True)


if __name__ == '__main__':
    main()
