"""Run a paired Flutter Android listener background/resume check on an owned QA stack."""

import argparse
import base64
import hashlib
import json
import math
import os
import shutil
import socket
import ssl
import struct
import subprocess
import tempfile
import time
import wave
from pathlib import Path

from tools.qa.critical_client_acceptance.stack import Stack
from tools.qa.local_features.native import verify_device


PACKAGE = 'ru.boohtacord.app'
CONTROL = 'issue785_flutter_pair_control.json'
ORIGIN = 'https://localhost:4810/api/v1'


def adb(device, *args, check=True):
    return subprocess.run(
        ['adb', '-s', device, *args],
        check=check,
        capture_output=True,
        text=True,
    )


def control_json(device):
    result = adb(device, 'shell', 'run-as', PACKAGE, 'cat', f'cache/{CONTROL}', check=False)
    if result.returncode:
        return None
    try:
        return json.loads(result.stdout)
    except json.JSONDecodeError as error:
        raise RuntimeError('Android QA control file was not valid JSON') from error


def set_control(device, status):
    encoded = base64.b64encode(json.dumps({'status': status}).encode()).decode()
    command = (
        f"run-as {PACKAGE} sh -c 'printf %s {encoded} | base64 -d > "
        f"cache/{CONTROL}.tmp && mv cache/{CONTROL}.tmp cache/{CONTROL}'"
    )
    adb(device, 'shell', command)


def create_synthetic_audio(path):
    rate = 48_000
    frames = bytearray()
    for index in range(rate * 2):
        sample = int(6000 * math.sin(2 * math.pi * 440 * index / rate))
        frames.extend(struct.pack('<h', sample))
    with wave.open(str(path), 'wb') as audio:
        audio.setnchannels(1)
        audio.setsampwidth(2)
        audio.setframerate(rate)
        audio.writeframes(frames)


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


def tail(path, limit=6000):
    try:
        return path.read_text(encoding='utf8', errors='replace')[-limit:]
    except FileNotFoundError:
        return ''


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--device', required=True)
    parser.add_argument('--background-seconds', type=int, default=300)
    parser.add_argument('--output', required=True)
    args = parser.parse_args()
    if args.background_seconds < 300:
        raise ValueError('Issue 785 Android background smoke must be at least 300 seconds')

    import re

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
    if control_json(device) is not None:
        raise FileExistsError('A stale Android pair QA control file exists')

    root_out = root / '.out'
    root_out.mkdir(exist_ok=True)
    work = Path(tempfile.mkdtemp(prefix='issue785-flutter-pair-', dir=root_out))
    stack = Stack(root, work)
    created_reverse = []
    node = None
    flutter = None
    input_path = work / 'pair-input.json'
    ready_path = work / 'pair-ready.json'
    final_path = work / 'pair-final.json'
    audio_path = work / 'synthetic-tone.wav'
    flutter_log = work / 'flutter-drive.log'
    node_log = work / 'sender.log'
    result_file = None
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
        create_synthetic_audio(audio_path)
        audio_path.chmod(0o600)
        sender_env = dict(os.environ, QA_PAIR_INPUT=str(input_path), QA_PAIR_READY=str(ready_path), QA_PAIR_FINAL=str(final_path), QA_AUDIO_WAV=str(audio_path))
        with node_log.open('w', encoding='utf8') as node_output:
            node = subprocess.Popen(
                ['node', 'tools/qa/critical_client_acceptance/issue785_flutter_background_pair.mjs'],
                cwd=root,
                env=sender_env,
                stdin=subprocess.PIPE,
                stdout=node_output,
                stderr=subprocess.STDOUT,
                text=True,
            )
            deadline = time.monotonic() + 120
            while not ready_path.exists() and time.monotonic() < deadline:
                if node.poll() is not None:
                    raise RuntimeError(f'Paired synthetic sender failed:\n{tail(node_log)}')
                time.sleep(.5)
            if not ready_path.exists():
                raise TimeoutError(f'Paired synthetic sender did not become ready:\n{tail(node_log)}')
            pair = json.loads(ready_path.read_text(encoding='utf8'))

            defines = work / 'defines.json'
            defines.write_text(json.dumps({
                'QA_API_BASE': ORIGIN,
                'QA_CERT_SHA256': pin,
                'QA_PASSWORD': stack.password,
                'QA_PAIR_ACCOUNT': pair['account'],
                'QA_PAIR_CHANNEL_ID': pair['channelId'],
            }), encoding='utf8')
            defines.chmod(0o600)
            capture_dir = output / 'screenshots'
            capture_dir.mkdir(exist_ok=True)
            flutter_env = dict(os.environ, BOOHTACORD_NATIVE_CAPTURE_DIR=str(capture_dir))
            flutter_args = [
                'flutter', 'drive', '--driver', 'test_driver/local_qa.dart',
                '--target', 'integration_test/issue785_background_listener_pair_test.dart',
                '-d', device, '--dart-define-from-file', str(defines),
            ]
            with flutter_log.open('w', encoding='utf8') as flutter_output:
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
                        raise RuntimeError(f'Flutter listener did not reach paired audio baseline:\n{tail(flutter_log)}')
                    time.sleep(1)
                else:
                    raise TimeoutError(f'Flutter receiver did not reach background handoff:\n{tail(flutter_log)}')

                adb(device, 'shell', 'input', 'keyevent', '3')
                launcher = wait_activity(device, re.compile(r'topResumedActivity=.*(?:nexuslauncher|Launcher)', re.I))
                background_services = adb(
                    device, 'shell', 'dumpsys', 'activity', 'services', PACKAGE,
                ).stdout
                microphone_service_active = bool(
                    re.search(r'(?i)(?:Microphone|VoiceMicrophone).*Service', background_services)
                )
                if microphone_service_active:
                    raise RuntimeError('Listener-only Flutter session unexpectedly started a microphone service')
                background_started = time.monotonic()
                print(f'Android Home observed; background duration target: {args.background_seconds}s', flush=True)
                while time.monotonic() - background_started < args.background_seconds:
                    if flutter.poll() is not None:
                        raise RuntimeError(f'Flutter integration exited while in Android Home:\n{tail(flutter_log)}')
                    elapsed = int(time.monotonic() - background_started)
                    if elapsed and elapsed % 60 == 0:
                        print(f'Android Home duration: {elapsed}s', flush=True)
                    time.sleep(min(1, args.background_seconds - (time.monotonic() - background_started)))
                observed_background = time.monotonic() - background_started
                adb(device, 'shell', 'am', 'start', '-n', f'{PACKAGE}/.MainActivity')
                wait_activity(device, re.compile(r'topResumedActivity=.*ru\.boohtacord\.app', re.I))
                set_control(device, 'resume')
                print('Android app resumed; waiting for Flutter receiver stats', flush=True)
                result_deadline = time.monotonic() + 120
                while time.monotonic() < result_deadline:
                    result_file = control_json(device)
                    if result_file and result_file.get('status') == 'complete':
                        (output / 'receiver-result.json').write_text(
                            json.dumps(result_file, indent=2) + '\n', encoding='utf8',
                        )
                        set_control(device, 'acknowledged')
                        break
                    if flutter.poll() is not None:
                        raise RuntimeError(f'Flutter integration exited before reporting receiver stats:\n{tail(flutter_log)}')
                    time.sleep(.25)
                if not result_file or result_file.get('status') != 'complete':
                    raise TimeoutError(f'Flutter receiver report was not delivered:\n{tail(flutter_log)}')
                try:
                    exit_code = flutter.wait(timeout=240)
                except subprocess.TimeoutExpired as error:
                    raise TimeoutError(f'Flutter pair test did not finish after resume:\n{tail(flutter_log)}') from error
                if exit_code != 0:
                    raise RuntimeError(f'Flutter pair test failed:\n{tail(flutter_log)}')

        if node is not None and node.poll() is None:
            node.stdin.write('STOP\n')
            node.stdin.flush()
            try:
                node.wait(timeout=30)
            except subprocess.TimeoutExpired:
                if not final_path.exists():
                    raise RuntimeError(f'Synthetic sender did not stop cleanly:\n{tail(node_log)}')
                node.terminate()
                node.wait(timeout=5)
        if not result_file or result_file.get('status') != 'complete':
            raise RuntimeError('Flutter pair test did not store its final receiver observations')
        if not final_path.exists():
            raise RuntimeError('Synthetic sender did not save its final outbound counters')
        sender_after = json.loads(final_path.read_text(encoding='utf8'))
        sender_result = {
            'beforeBackground': pair['senderInitial'],
            'afterBackground': sender_after['outboundAudioCounters'],
        }
        if sender_result['afterBackground']['outboundAudioBytes'] <= sender_result['beforeBackground']['outboundAudioBytes']:
            raise RuntimeError('Synthetic sender audio bytes did not advance during the Flutter background run')
        adb(device, 'shell', 'run-as', PACKAGE, 'rm', '-f', f'cache/{CONTROL}', check=False)
        result = {
            'status': 'PASS_SCOPED',
            'issue': 785,
            'environment': {
                'runtime': 'Android 15 / API 35 AOSP ARM64 emulator',
                'avd': 'BOOHTACORD_QA_API35',
                'device': device,
                'physical_device': False,
                'receiver': 'Flutter Android listener-only client',
                'sender': 'Playwright Chromium with synthetic microphone input',
                'server': 'Owned disposable API/PostgreSQL/LiveKit QA stack',
            },
            'scenario': {
                'receiver_microphone': 'disabled; listener-only with no local audio publications',
                'background_action': 'Android Home; sender continued publishing',
                'home_activity_observed': bool(launcher),
                'background_seconds_requested': args.background_seconds,
                'background_seconds_observed': round(observed_background, 3),
                'microphone_foreground_service_active': microphone_service_active,
                'voice_phase_after_resume': result_file['result']['voicePhase'],
                'application_socket_connected_after_resume': result_file['result']['applicationSocketConnected'],
            },
            'receiver_media': result_file['result'],
            'sender_media': sender_result,
            'media_result': 'PASS_SCOPED: LiveKit receiver packet/byte counters advanced after resume; acoustic output was not measured',
            'runtime_log': str(output / 'flutter-drive.log'),
            'screenshots': str(capture_dir),
            'limitations': [
                'Emulator RTP and audio receiver statistics do not prove audio reached the speaker or was audible to a person.',
                'This is a five-minute emulator run, not a physical-device or 60-minute acceptance.',
                'No screen lock, secure keyguard, network transition, airplane mode, process kill, permission revoke, battery saver, iOS, or production release was tested.',
                'Issue 785 release gate remains open.',
            ],
        }
        (output / 'result.json').write_text(json.dumps(result, indent=2) + '\n', encoding='utf8')
        print('RESULT=' + json.dumps(result), flush=True)
    except Exception:
        if flutter_log.exists():
            shutil.copy2(flutter_log, output / 'flutter-drive.log')
        if node_log.exists():
            shutil.copy2(node_log, output / 'sender.log')
        raise
    finally:
        try:
            if flutter is not None and flutter.poll() is None:
                flutter.terminate()
                try:
                    flutter.wait(timeout=10)
                except subprocess.TimeoutExpired:
                    flutter.kill()
            if node is not None and node.poll() is None:
                try:
                    node.stdin.write('STOP\n')
                    node.stdin.flush()
                    node.wait(timeout=15)
                except (BrokenPipeError, subprocess.TimeoutExpired):
                    node.terminate()
            if node is not None and node.returncode not in (None, 0):
                print(f'Sender log:\n{tail(node_log)}')
        finally:
            try:
                stack.close()
            finally:
                for port in reversed(created_reverse):
                    adb(device, 'reverse', '--remove', f'tcp:{port}', check=False)
                shutil.rmtree(work, ignore_errors=True)


if __name__ == '__main__':
    main()
