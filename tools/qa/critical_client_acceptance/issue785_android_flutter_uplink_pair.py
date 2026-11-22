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
import struct
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


def validate_service_stop_after(seconds, background_seconds):
    if seconds < 0:
        raise ValueError('Service-stop probe offset cannot be negative')
    if seconds and seconds >= background_seconds:
        raise ValueError('Service-stop probe must occur inside the background interval')
    return seconds


def validate_microphone_permission_revoke_after(seconds, background_seconds):
    if seconds < 0:
        raise ValueError('Microphone permission-revoke offset cannot be negative')
    if seconds and seconds >= background_seconds:
        raise ValueError('Permission-revoke probe must occur inside the background interval')
    return seconds


def validate_permission_revoke_cold_start(enabled, permission_revoke_after):
    if enabled and permission_revoke_after <= 0:
        raise ValueError('Cold-start probe requires a microphone permission-revoke injection')
    return enabled


def flutter_drive_cleanup_flags(preserve_package_for_cold_start):
    return ['--keep-app-running'] if preserve_package_for_cold_start else []


def normal_product_apk_install_command(device, apk_path):
    return ['adb', '-s', device, 'install', '-r', '-d', str(apk_path)]


def build_web_client(root, public_origin):
    owned_origin = ORIGIN.removesuffix('/api/v1')
    if public_origin != owned_origin:
        raise ValueError('Paired Android QA must build the browser client for its owned loopback origin')
    subprocess.run(
        ['npm', 'run', 'build'],
        cwd=Path(root) / 'clients/web',
        env=dict(os.environ, VITE_PUBLIC_ORIGIN=public_origin),
        stdout=subprocess.DEVNULL,
        check=True,
    )


def build_normal_product_apk(root, work):
    flutter_root = Path(root) / 'clients/flutter'
    built_apk = flutter_root / 'build/app/outputs/flutter-apk/app-debug.apk'
    preserved_apk = Path(work) / 'normal-product-app-debug.apk'
    build_log = Path(work) / 'normal-product-apk-build.log'
    with build_log.open('w', encoding='utf8') as log:
        result = subprocess.run(
            ['flutter', 'build', 'apk', '--debug', '--no-pub'],
            cwd=flutter_root,
            stdout=log,
            stderr=subprocess.STDOUT,
            text=True,
            check=False,
        )
    if result.returncode:
        raise RuntimeError(
            'Ordinary Flutter product APK build failed:\n' + tail(build_log, limit=3000)
        )
    if not built_apk.is_file() or built_apk.stat().st_size == 0:
        raise RuntimeError('Flutter product APK build produced no app-debug.apk')
    shutil.copy2(built_apk, preserved_apk)
    digest = hashlib.sha256(preserved_apk.read_bytes()).hexdigest()
    return preserved_apk, digest


def microphone_permission_status(package_dump):
    match = re.search(
        r'(?mi)^\s*android\.permission\.RECORD_AUDIO:\s*granted=(true|false)\b',
        package_dump,
    )
    if match is None:
        return None
    return 'granted' if match.group(1).lower() == 'true' else 'denied'


def permission_revoke_permission_persisted(permission_status_before_launch, package_dump_after_launch):
    return (
        permission_status_before_launch == 'denied'
        and microphone_permission_status(package_dump_after_launch) == 'denied'
    )


def permission_revoke_cold_start_result(permission_status, app_pid, activity_dump, service_dump):
    if permission_status.strip().lower() != 'denied' or not app_pid:
        return None
    if not re.search(r'(?i)topResumedActivity=.*ru\.boohtacord\.app/.*MainActivity', activity_dump):
        return None
    if microphone_foreground_service_active(service_dump):
        return None
    return {
        'status': 'PASS_SCOPED',
        'permission_status': 'denied',
        'app_installed': True,
        'app_process_running': True,
        'main_activity_resumed': True,
        'microphone_foreground_service_active': False,
    }


def permission_revoke_cold_start_not_run(permission_status, reason, *, app_installed=False):
    return {
        'status': 'NOT_RUN',
        'permission_status': permission_status,
        'app_installed': app_installed,
        'app_process_running': False,
        'main_activity_resumed': False,
        'microphone_foreground_service_active': 'NOT_VERIFIED',
        'automatic_voice_rejoin': 'NOT_RUN',
        'reason': reason,
    }


def microphone_service_expected_active(sample_offset, stop_after):
    return not stop_after or sample_offset < stop_after


def service_stop_command_succeeded(returncode, stdout, stderr):
    if returncode == 0:
        return True
    return 'Service stopped' in {
        line.strip() for line in f'{stdout}\n{stderr}'.splitlines()
    }


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


def receiver_media_stop_after_permission_revoke(samples, revoked_at_unix_ms, end_unix_ms, settle_seconds=10):
    samples = sorted(samples, key=lambda sample: sample.get('observed_at_unix_ms', -1))
    before = [
        sample for sample in samples
        if sample.get('observed_at_unix_ms', -1) < revoked_at_unix_ms
        and receiver_has_foreground_uplink(sample)
    ]
    settled = [
        sample for sample in samples
        if revoked_at_unix_ms + settle_seconds * 1000
        <= sample.get('observed_at_unix_ms', -1) <= end_unix_ms
    ]
    if not before or len(settled) < 2:
        return None
    if settled[-1].get('observed_at_unix_ms', -1) < end_unix_ms - 3000:
        return None
    if settled[-1]['observed_at_unix_ms'] - settled[0]['observed_at_unix_ms'] < settle_seconds * 1000:
        return None
    if any(
        following.get('inbound_audio_packets', 0) > current.get('inbound_audio_packets', 0)
        or following.get('inbound_audio_bytes', 0) > current.get('inbound_audio_bytes', 0)
        for current, following in zip(settled, settled[1:])
    ):
        return None
    before_packets = before[-1].get('inbound_audio_packets', 0)
    before_bytes = before[-1].get('inbound_audio_bytes', 0)
    latest_increment = None
    max_packets = before_packets
    max_bytes = before_bytes
    for sample in samples:
        if sample.get('observed_at_unix_ms', -1) < revoked_at_unix_ms:
            continue
        packets = sample.get('inbound_audio_packets', 0)
        byte_count = sample.get('inbound_audio_bytes', 0)
        if packets > max_packets or byte_count > max_bytes:
            latest_increment = sample
            max_packets = max(max_packets, packets)
            max_bytes = max(max_bytes, byte_count)
    first, last = settled[0], settled[-1]
    return {
        'receiver_before_revoke': before[-1],
        'receiver_after_settle': first,
        'receiver_at_background_end': last,
        'last_rtp_counter_increase_after_revoke': latest_increment,
        'settle_window_samples': len(settled),
        'settle_seconds': settle_seconds,
        'plateau_observed_seconds': round(
            (last['observed_at_unix_ms'] - first['observed_at_unix_ms']) / 1000,
            3,
        ),
        'final_sample_lag_seconds': round(
            (end_unix_ms - last['observed_at_unix_ms']) / 1000,
            3,
        ),
    }


def receiver_has_foreground_uplink(sample):
    return bool(
        sample
        and sample.get('inbound_audio_tracks', 0) > 0
        and sample.get('inbound_audio_packets', 0) > 0
        and sample.get('inbound_audio_bytes', 0) > 0
    )


def receiver_uplink_advanced_after(samples, started_at_unix_ms, timeout_seconds=20):
    deadline = started_at_unix_ms + timeout_seconds * 1000
    after = [
        sample for sample in samples
        if started_at_unix_ms <= sample.get('observed_at_unix_ms', -1) <= deadline
    ]
    for previous, current in zip(after, after[1:]):
        if (
            current.get('inbound_audio_tracks', 0) > 0
            and current.get('inbound_audio_packets', 0) > previous.get('inbound_audio_packets', 0)
            and current.get('inbound_audio_bytes', 0) > previous.get('inbound_audio_bytes', 0)
        ):
            return {
                'sample_before_progress': previous,
                'first_progress_sample': current,
                'progress_seconds_after_action': round(
                    (current['observed_at_unix_ms'] - started_at_unix_ms) / 1000,
                    3,
                ),
            }
    return None


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
        # Flutter writes its first ready marker directly into the cache file.
        # A polling read can briefly observe that write before it is complete.
        return None


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


def permission_revoke_process_kill_log(device):
    logcat = adb(
        device,
        'logcat',
        '-d',
        '-s',
        'ActivityManager:I',
        'AppOps:E',
    ).stdout
    latest_kill = latest_permission_revoke_kill(logcat)
    if latest_kill is None:
        raise RuntimeError(
            'App process disappeared after permission revoke, but AVD logcat did not confirm an Android permission-revocation process kill'
        )
    return [latest_kill]


def latest_permission_revoke_kill(logcat):
    observations = [
        line for line in logcat.splitlines()
        if PACKAGE.lower() in line.lower()
        and 'permissions revoked' in line.lower()
    ]
    return observations[-1] if observations else None


def relaunch_after_permission_revoke(
    device,
    output,
    root,
    permission_status,
    normal_product_apk,
    normal_product_apk_sha256,
    flutter_driver,
):
    if permission_status != 'denied':
        raise RuntimeError('RECORD_AUDIO was not denied before the cold-start probe')
    if flutter_driver is not None and flutter_driver.poll() is None:
        try:
            flutter_driver.wait(timeout=15)
        except subprocess.TimeoutExpired:
            return permission_revoke_cold_start_not_run(
                permission_status,
                'Flutter integration driver did not exit after Android killed its app process',
                app_installed=True,
            )
    if not normal_product_apk.is_file():
        return permission_revoke_cold_start_not_run(
            permission_status,
            'Ordinary Flutter product APK was not available for the cold-start probe',
            app_installed=True,
        )
    install = subprocess.run(
        normal_product_apk_install_command(device, normal_product_apk),
        capture_output=True,
        text=True,
        check=False,
    )
    if install.returncode:
        return permission_revoke_cold_start_not_run(
            permission_status,
            'Ordinary Flutter product APK could not replace the integration-test APK',
            app_installed=True,
        )
    installed_path = adb(device, 'shell', 'pm', 'path', PACKAGE, check=False).stdout.strip()
    if not installed_path.startswith('package:'):
        return permission_revoke_cold_start_not_run(
            permission_status,
            'Application package was absent after installing the ordinary Flutter product APK',
        )
    launched = adb(
        device,
        'shell',
        'am',
        'start',
        '-n',
        f'{PACKAGE}/.MainActivity',
        check=False,
    )
    if launched.returncode:
        return permission_revoke_cold_start_not_run(
            permission_status,
            'Android launcher activity was unavailable after the integration process exited',
            app_installed=True,
        )

    deadline = time.monotonic() + 45
    cold_start = None
    while time.monotonic() < deadline:
        app_pid = adb(device, 'shell', 'pidof', PACKAGE, check=False).stdout.strip()
        activity_dump = adb(device, 'shell', 'dumpsys', 'activity', 'activities').stdout
        service_dump = adb(
            device,
            'shell',
            'dumpsys',
            'activity',
            'services',
            PACKAGE,
            check=False,
        ).stdout
        cold_start = permission_revoke_cold_start_result(
            permission_status,
            app_pid,
            activity_dump,
            service_dump,
        )
        if cold_start:
            break
        time.sleep(.5)
    if cold_start is None:
        raise RuntimeError(
            'Cold start did not restore the main Activity with RECORD_AUDIO denied and microphone FGS inactive'
        )

    time.sleep(3)
    package_state = adb(
        device,
        'shell',
        'dumpsys',
        'package',
        PACKAGE,
        check=False,
    )
    permission_status_after_relaunch = microphone_permission_status(package_state.stdout)
    if not permission_revoke_permission_persisted(permission_status, package_state.stdout):
        raise RuntimeError('RECORD_AUDIO was not still denied after the cold-start probe')
    service_dump = adb(
        device,
        'shell',
        'dumpsys',
        'activity',
        'services',
        PACKAGE,
        check=False,
    ).stdout
    if microphone_foreground_service_active(service_dump):
        raise RuntimeError('Microphone FGS started after cold launch while RECORD_AUDIO remained denied')
    app_pid = adb(device, 'shell', 'pidof', PACKAGE, check=False).stdout.strip()
    if not app_pid:
        raise RuntimeError('App process exited after its permission-revoked cold start')

    screenshot = output / 'after-permission-revoke-cold-start.png'
    capture = subprocess.run(
        ['adb', '-s', device, 'exec-out', 'screencap', '-p'],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=True,
    )
    if not capture.stdout.startswith(b'\x89PNG\r\n\x1a\n'):
        raise RuntimeError('Android cold-start screenshot was not a PNG image')
    screenshot.write_bytes(capture.stdout)
    width, height = struct.unpack('>II', capture.stdout[16:24])
    cold_start.update({
        'activity_component': f'{PACKAGE}/.MainActivity',
        'microphone_permission_revoked': True,
        'permission_status_after_relaunch': permission_status_after_relaunch,
        'ordinary_product_apk_installed': True,
        'ordinary_product_apk_sha256': normal_product_apk_sha256,
        'screenshot': str(screenshot.relative_to(root)),
        'screenshot_sha256': hashlib.sha256(capture.stdout).hexdigest(),
        'screenshot_resolution_px': [width, height],
        'automatic_voice_rejoin': 'NOT_RUN',
    })
    adb(device, 'shell', 'input', 'keyevent', '3')
    wait_activity(device, re.compile(r'topResumedActivity=.*(?:nexuslauncher|Launcher)', re.I))
    return cold_start


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--device', required=True)
    parser.add_argument('--background-seconds', type=int, default=DEFAULT_BACKGROUND_SECONDS)
    parser.add_argument('--background-action', choices=('home', 'screen-off'), default='home')
    parser.add_argument('--blackhole-seconds', type=int, default=0)
    parser.add_argument('--service-stop-after-seconds', type=int, default=0)
    parser.add_argument('--microphone-permission-revoke-after-seconds', type=int, default=0)
    parser.add_argument('--relaunch-after-permission-revoke', action='store_true')
    parser.add_argument('--output', required=True)
    args = parser.parse_args()
    validate_background_seconds(args.background_seconds)
    validate_blackhole_seconds(args.background_seconds, args.blackhole_seconds)
    validate_service_stop_after(args.service_stop_after_seconds, args.background_seconds)
    validate_microphone_permission_revoke_after(
        args.microphone_permission_revoke_after_seconds,
        args.background_seconds,
    )
    validate_permission_revoke_cold_start(
        args.relaunch_after_permission_revoke,
        args.microphone_permission_revoke_after_seconds,
    )
    if args.service_stop_after_seconds and args.microphone_permission_revoke_after_seconds:
        raise ValueError('Choose either service-stop or permission-revoke injection')
    microphone_intervention_after = (
        args.service_stop_after_seconds or args.microphone_permission_revoke_after_seconds
    )

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
    service_stop_injected = False
    service_stop_started_unix_ms = 0
    service_stop_observed_offset = 0.0
    microphone_permission_revoke_injected = False
    permission_revoke_started_unix_ms = 0
    permission_revoke_observed_offset = 0.0
    permission_revoke_process_exit_observed = False
    permission_revoke_process_exit_offset = 0.0
    permission_revoke_kill_log = []
    permission_revoke_cold_start = None
    permission_revoke_permission_status = None
    normal_product_apk = None
    normal_product_apk_sha256 = None
    try:
        os.environ.update({
            'DOCKER_CONTEXT': 'colima-boohtacord-qa',
            'BOOHTACORD_QA_EGRESS_PLATFORM': 'linux/amd64',
            'VITE_PUBLIC_ORIGIN': ORIGIN.removesuffix('/api/v1'),
            'QA_ORIGIN': ORIGIN.removesuffix('/api/v1'),
            'QA_DB_OWNER': stack.owner,
        })
        build_web_client(root, ORIGIN.removesuffix('/api/v1'))
        if args.relaunch_after_permission_revoke:
            normal_product_apk, normal_product_apk_sha256 = build_normal_product_apk(
                root,
                work,
            )
            print(
                'Built ordinary Flutter product APK for the post-revoke cold-start probe: '
                f'{normal_product_apk_sha256}',
                flush=True,
            )
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
                'QA_EXPECT_MICROPHONE_SERVICE_STOP': args.service_stop_after_seconds > 0,
                'QA_EXPECT_MICROPHONE_PERMISSION_REVOKE': args.microphone_permission_revoke_after_seconds > 0,
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
            flutter_args.extend(
                flutter_drive_cleanup_flags(args.relaunch_after_permission_revoke)
            )
            with flutter_log.open('w', encoding='utf8') as flutter_output:
                with android_microphone_permission(
                    'android', device,
                    'integration_test/issue785_background_microphone_uplink_test.dart',
                    regrant=not bool(args.microphone_permission_revoke_after_seconds),
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
                        elapsed = time.monotonic() - background_started
                        if (
                            microphone_permission_revoke_injected
                            and not permission_revoke_process_exit_observed
                            and not adb(device, 'shell', 'pidof', PACKAGE, check=False).stdout.strip()
                        ):
                            permission_revoke_process_exit_observed = True
                            permission_revoke_process_exit_offset = elapsed
                            permission_revoke_kill_log = permission_revoke_process_kill_log(device)
                            print(
                                'Android terminated the app process after RECORD_AUDIO revocation; '
                                'continuing the independent receiver and service observation window',
                                flush=True,
                            )
                            if args.relaunch_after_permission_revoke:
                                permission_revoke_cold_start = relaunch_after_permission_revoke(
                                    device,
                                    output,
                                    root,
                                    permission_revoke_permission_status,
                                    normal_product_apk,
                                    normal_product_apk_sha256,
                                    flutter,
                                )
                        if flutter.poll() is not None:
                            if not (args.microphone_permission_revoke_after_seconds and microphone_permission_revoke_injected):
                                raise RuntimeError(f'Flutter integration exited while backgrounded:\n{tail(flutter_log, stack.password)}')
                            if not permission_revoke_process_exit_observed:
                                app_process = adb(device, 'shell', 'pidof', PACKAGE, check=False).stdout.strip()
                                if app_process:
                                    raise RuntimeError(
                                        'Flutter driver exited after RECORD_AUDIO revoke while the app process was still running'
                                    )
                                permission_revoke_process_exit_observed = True
                                permission_revoke_process_exit_offset = elapsed
                                permission_revoke_kill_log = permission_revoke_process_kill_log(device)
                                print(
                                    'Android terminated the app process after RECORD_AUDIO revocation; '
                                    'continuing the independent receiver and service observation window',
                                    flush=True,
                                )
                                if args.relaunch_after_permission_revoke:
                                    permission_revoke_cold_start = relaunch_after_permission_revoke(
                                        device,
                                        output,
                                        root,
                                        permission_revoke_permission_status,
                                        normal_product_apk,
                                        normal_product_apk_sha256,
                                        flutter,
                                    )
                        if (
                            args.service_stop_after_seconds
                            and not service_stop_injected
                            and elapsed >= args.service_stop_after_seconds
                        ):
                            stopped = adb(
                                device,
                                'shell',
                                'run-as',
                                PACKAGE,
                                'am',
                                'stopservice',
                                '--user',
                                '0',
                                '-n',
                                f'{PACKAGE}/ru.boohtacord.voice.start.MicrophoneService',
                                check=False,
                            )
                            if not service_stop_command_succeeded(
                                stopped.returncode,
                                stopped.stdout,
                                stopped.stderr,
                            ):
                                raise RuntimeError(
                                    'ADB could not inject the scoped microphone service stop: '
                                    f'code={stopped.returncode}; '
                                    f'stdout={stopped.stdout.strip()!r}; '
                                    f'stderr={stopped.stderr.strip()!r}'
                                )
                            service_stop_injected = True
                            service_stop_started_unix_ms = int(time.time() * 1000)
                            service_stop_observed_offset = elapsed
                            print(
                                'Injected explicit adb stopService for the microphone FGS; '
                                'this is not an OS-forced stop scenario',
                                flush=True,
                            )
                        if (
                            args.microphone_permission_revoke_after_seconds
                            and not microphone_permission_revoke_injected
                            and elapsed >= args.microphone_permission_revoke_after_seconds
                        ):
                            revoked = adb(
                                device,
                                'shell',
                                'pm',
                                'revoke',
                                PACKAGE,
                                'android.permission.RECORD_AUDIO',
                                check=False,
                            )
                            if revoked.returncode:
                                raise RuntimeError(
                                    'ADB could not revoke microphone permission: '
                                    f'code={revoked.returncode}; '
                                    f'stdout={revoked.stdout.strip()!r}; '
                                    f'stderr={revoked.stderr.strip()!r}'
                                )
                            microphone_permission_revoke_injected = True
                            permission_revoke_started_unix_ms = int(time.time() * 1000)
                            permission_revoke_observed_offset = elapsed
                            if args.relaunch_after_permission_revoke:
                                package_state = adb(
                                    device,
                                    'shell',
                                    'dumpsys',
                                    'package',
                                    PACKAGE,
                                    check=False,
                                )
                                permission_revoke_permission_status = microphone_permission_status(
                                    package_state.stdout
                                )
                                if permission_revoke_permission_status != 'denied':
                                    permission_lines = [
                                        line.strip() for line in package_state.stdout.splitlines()
                                        if 'RECORD_AUDIO' in line
                                    ]
                                    raise RuntimeError(
                                        'Could not confirm denied RECORD_AUDIO after revoke; '
                                        f'dumpsys matches={permission_lines!r}'
                                    )
                            print(
                                'Revoked RECORD_AUDIO with adb pm revoke; '
                                'this is a controlled permission change, not an OS process-kill scenario',
                                flush=True,
                            )
                            if args.relaunch_after_permission_revoke:
                                process_dead_deadline = time.monotonic() + 10
                                while time.monotonic() < process_dead_deadline:
                                    if not adb(device, 'shell', 'pidof', PACKAGE, check=False).stdout.strip():
                                        break
                                    time.sleep(.1)
                                if adb(device, 'shell', 'pidof', PACKAGE, check=False).stdout.strip():
                                    raise RuntimeError(
                                        'Android did not terminate the app process after RECORD_AUDIO revocation'
                                    )
                                permission_revoke_process_exit_observed = True
                                permission_revoke_process_exit_offset = time.monotonic() - background_started
                                permission_revoke_kill_log = permission_revoke_process_kill_log(device)
                                print(
                                    'Android terminated the app process after RECORD_AUDIO revocation; '
                                    'launching it again immediately on the AVD',
                                    flush=True,
                                )
                                permission_revoke_cold_start = relaunch_after_permission_revoke(
                                    device,
                                    output,
                                    root,
                                    permission_revoke_permission_status,
                                    normal_product_apk,
                                    normal_product_apk_sha256,
                                    flutter,
                                )
                                permission_revoke_cold_start['launched_after_revoke_offset_seconds'] = round(
                                    time.monotonic() - background_started,
                                    3,
                                )
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
                                'service_stop_injected': service_stop_injected,
                                'microphone_permission_revoked': microphone_permission_revoke_injected,
                            })
                            if microphone_service_expected_active(elapsed, microphone_intervention_after) and not active:
                                raise RuntimeError(f'Microphone foreground service stopped during Android {args.background_action}')
                            if (service_stop_injected or microphone_permission_revoke_injected) and active:
                                raise RuntimeError('Microphone FGS remained active after the injected microphone intervention')
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
                        'service_stop_injected': service_stop_injected,
                        'microphone_permission_revoked': microphone_permission_revoke_injected,
                    })
                    if not microphone_intervention_after and not active:
                        raise RuntimeError(f'Microphone foreground service was not active at the end of Android {args.background_action}')
                    if microphone_intervention_after and (
                        not (service_stop_injected or microphone_permission_revoke_injected) or active
                    ):
                        raise RuntimeError('The injected microphone intervention was not observed by the end of the background interval')
                    if args.background_action == 'screen-off' and not final_display_asleep:
                        raise RuntimeError('Android display was awake at the end of the screen-off background interval')
                    if permission_revoke_process_exit_observed:
                        app_process = adb(device, 'shell', 'pidof', PACKAGE, check=False).stdout.strip()
                        if app_process and permission_revoke_cold_start is None:
                            raise RuntimeError('Flutter driver exited after permission revoke, but the Android app process is still running')
                        if permission_revoke_cold_start is not None:
                            permission_revoke_cold_start['app_process_running_at_window_end'] = bool(app_process)
                    else:
                        set_control(
                            device,
                            'resume',
                            backgroundSecondsObserved=round(observed_background, 3),
                            backgroundStartedUnixMs=background_started_unix_ms,
                            backgroundEndedUnixMs=background_ended_unix_ms,
                            microphoneServiceSamples=microphone_samples,
                            expectedMicrophoneServiceStop=bool(args.service_stop_after_seconds),
                            expectedMicrophonePermissionRevoke=bool(args.microphone_permission_revoke_after_seconds),
                            microphoneServiceStopStartedUnixMs=service_stop_started_unix_ms,
                            microphoneServiceStopOffsetSeconds=round(service_stop_observed_offset, 3),
                            microphonePermissionRevokeStartedUnixMs=permission_revoke_started_unix_ms,
                            microphonePermissionRevokeOffsetSeconds=round(permission_revoke_observed_offset, 3),
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
        microphone_retry_after_service_stop = None
        if args.service_stop_after_seconds:
            retry_result = (result_file or {}).get('result', {}).get(
                'microphoneRetryAfterServiceStop'
            )
            if not retry_result or not retry_result.get('retryStartedAtUnixMs'):
                raise RuntimeError('Flutter did not report a microphone retry after the controlled FGS stop')
            retry_receiver_progress = receiver_uplink_advanced_after(
                samples,
                retry_result['retryStartedAtUnixMs'],
            )
            if retry_receiver_progress is None:
                raise RuntimeError('Independent receiver saw no inbound RTP progress after microphone Retry')
            microphone_retry_after_service_stop = {
                **retry_result,
                'independentReceiverRtp': retry_receiver_progress,
            }
        revoke_media = None
        if permission_revoke_process_exit_observed:
            revoke_media = receiver_media_stop_after_permission_revoke(
                samples,
                permission_revoke_started_unix_ms,
                background_ended_unix_ms,
            )
            if revoke_media is None:
                raise RuntimeError(
                    'Independent receiver RTP counters did not plateau after RECORD_AUDIO revoke and its settle window'
                )
        elif not receiver_progressed_during_background(
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
        if len(microphone_samples) < 5:
            raise RuntimeError('Microphone FGS samples did not cover the full background interval')
        if microphone_intervention_after:
            if not microphone_samples[0]['microphone_foreground_service_active'] or any(
                sample['microphone_foreground_service_active']
                for sample in microphone_samples
                if sample['offset_seconds'] >= microphone_intervention_after
            ):
                raise RuntimeError('AVD microphone intervention did not transition the FGS active to stopped')
        elif not all(sample['microphone_foreground_service_active'] for sample in microphone_samples):
            raise RuntimeError('Microphone FGS continuity was not observed across the full background interval')

        adb(device, 'shell', 'run-as', PACKAGE, 'rm', '-f', f'cache/{CONTROL}', check=False)
        post_leave = adb(device, 'shell', 'dumpsys', 'activity', 'services', PACKAGE, check=False).stdout
        cleanup = not microphone_foreground_service_active(post_leave)
        if permission_revoke_process_exit_observed:
            result = {
                'status': 'PASS_SCOPED',
                'issue': 785,
                'source': {
                    'working_tree_head': subprocess.check_output(
                        ['git', 'rev-parse', 'HEAD'], cwd=root, text=True,
                    ).strip(),
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
                    'background_action': 'Android Home',
                    'background_seconds_requested': args.background_seconds,
                    'background_seconds_observed': round(observed_background, 3),
                    'microphone_foreground_service_samples': microphone_samples,
                    'microphone_service_inactive_through_final_sample': cleanup,
                    'permission_revoke_probe': {
                        'kind': 'adb pm revoke android.permission.RECORD_AUDIO; Android process termination confirmed in ActivityManager logcat',
                        'injected': microphone_permission_revoke_injected,
                        'offset_seconds': round(permission_revoke_observed_offset, 3),
                        'flutter_driver_exit_offset_seconds': round(permission_revoke_process_exit_offset, 3),
                        'app_process_absent_at_window_end': not bool(
                            adb(device, 'shell', 'pidof', PACKAGE, check=False).stdout.strip()
                        ),
                        'log_observations': permission_revoke_kill_log,
                    },
                    'receiver_media_stop': revoke_media,
                    'service_cleanup_observed': cleanup,
                    'fallback_ui': (
                        'NOT_ASSERTED; cold-start screenshot only'
                        if permission_revoke_cold_start and permission_revoke_cold_start['status'] == 'PASS_SCOPED'
                        else 'NOT_RUN; cold-start probe could not relaunch the app'
                        if permission_revoke_cold_start
                        else 'NOT_RUN; Android terminated the app process'
                    ),
                    'rejoin_after_relaunch': 'NOT_RUN',
                    'acoustic_output': 'NOT_MEASURED',
                },
                'receiver_media': receiver_result,
                'limitations': [
                    'This scoped result covers permission-revocation process termination, microphone FGS inactivity, and receiver RTP plateau only.',
                    'Fallback/retry UI and automatic voice rejoin were not asserted after Android terminated the process.',
                    'RTP counters prove transport cessation, not acoustic audibility.',
                    'This is a 120-second AOSP AVD run, not physical Android acceptance.',
                    'Issue 785 release gate remains open.',
                ],
            }
            if permission_revoke_cold_start is not None and permission_revoke_cold_start['status'] == 'PASS_SCOPED':
                result['scenario']['cold_start_after_permission_revoke'] = permission_revoke_cold_start
                result['limitations'] = [
                    'This scoped result covers permission-revocation process termination, microphone FGS inactivity and a cold app launch with RECORD_AUDIO still denied.',
                    'No fallback notice assertion or automatic voice rejoin was performed after relaunch.',
                    'RTP counters prove transport cessation, not acoustic audibility.',
                    'This is a 120-second AOSP AVD run, not physical Android acceptance.',
                    'Issue 785 release gate remains open.',
                ]
            elif permission_revoke_cold_start is not None:
                result['scenario']['cold_start_after_permission_revoke'] = permission_revoke_cold_start
                result['limitations'] = [
                    'This scoped result covers permission-revocation process termination, microphone FGS inactivity and receiver RTP plateau only.',
                    'Cold-start recovery was NOT_RUN because the app package was absent from the AVD after the integration process exited.',
                    'No fallback notice assertion, automatic voice rejoin or acoustic output measurement was performed.',
                    'This is a 120-second AOSP AVD run, not physical Android acceptance.',
                    'Issue 785 release gate remains open.',
                ]
            (output / 'receiver-result.json').write_text(
                json.dumps(receiver_result, indent=2) + '\n', encoding='utf8',
            )
            (output / 'result.json').write_text(json.dumps(result, indent=2) + '\n', encoding='utf8')
            shutil.copy2(flutter_log, output / 'flutter-drive.log')
            shutil.copy2(receiver_log, output / 'receiver.log')
            print('RESULT=' + json.dumps(result), flush=True)
            return

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
                'microphone_service_stop_probe': {
                    'kind': 'explicit adb am stopservice; not a system-forced stop',
                    'injected': service_stop_injected,
                    'offset_seconds': round(service_stop_observed_offset, 3),
                    'started_at_unix_ms': service_stop_started_unix_ms,
                } if args.service_stop_after_seconds else None,
                'microphone_permission_revoke_probe': {
                    'kind': 'adb pm revoke android.permission.RECORD_AUDIO; not an OS process kill',
                    'injected': microphone_permission_revoke_injected,
                    'offset_seconds': round(permission_revoke_observed_offset, 3),
                    'started_at_unix_ms': permission_revoke_started_unix_ms,
                } if args.microphone_permission_revoke_after_seconds else None,
                'microphone_retry_after_service_stop': microphone_retry_after_service_stop,
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
