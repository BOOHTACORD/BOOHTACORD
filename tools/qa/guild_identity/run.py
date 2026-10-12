"""Run isolated native guild identity QA and retain its actual provenance."""
import argparse
import hashlib
import json
import os
import socket
import ssl
import subprocess
import tempfile
from datetime import datetime, timezone
from pathlib import Path

from tools.qa.guild_identity.stack import Stack
from tools.qa.local_features.native import verify_device
from tools.qa.local_features.process import run_owned


def current_identity(root):
    """Read the checkout and toolchain before starting any runtime resources."""
    candidate = subprocess.check_output(
        ['git', 'rev-parse', 'HEAD'], cwd=root, text=True,
    ).strip()
    toolchain = json.loads(subprocess.check_output(
        ['flutter', '--version', '--machine'], cwd=root, text=True,
    ))
    return {
        'candidate': candidate,
        'flutter': toolchain['frameworkVersion'],
        'dart': toolchain['dartSdkVersion'],
        'flutter_framework_revision': toolchain['frameworkRevision'],
    }


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--platform', choices=['android', 'ios'], default='android')
    parser.add_argument('--device', default='emulator-5558')
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[3]
    sdk = '/opt/homebrew/share/android-commandlinetools'
    os.environ.setdefault('ANDROID_HOME', sdk)
    os.environ.setdefault('ANDROID_SDK_ROOT', sdk)
    os.environ.setdefault('JAVA_HOME', '/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home')
    os.environ.setdefault('DOCKER_CONTEXT', 'colima-boohtacord-qa')
    os.environ['PATH'] = sdk + '/platform-tools:/opt/homebrew/bin:' + os.environ.get('PATH', '')
    identity = current_identity(root)
    started = datetime.now(timezone.utc).isoformat()
    destination = root / '.out/qa278' / args.platform
    destination.mkdir(parents=True, exist_ok=True)
    device = args.device
    verify_device(args.platform, device)
    if args.platform == 'android':
        previous = subprocess.check_output(
            ['adb', '-s', device, 'reverse', '--list'], text=True,
        )
        if 'tcp:4840' in previous:
            raise ValueError('Port reverse already owned by another run')
        subprocess.run(
            ['adb', '-s', device, 'reverse', 'tcp:4840', 'tcp:4840'],
            check=True, stdout=subprocess.DEVNULL,
        )
    try:
        with tempfile.TemporaryDirectory(
            prefix='qa278-',
            dir=os.environ.get('BOOHTACORD_QA_SHARED_WORK', str(root / '.out')),
        ) as directory:
            work = Path(directory)
            stack = Stack(root, work)
            try:
                stack.start()
                with socket.create_connection(('127.0.0.1', 4840)) as plain:
                    context = ssl._create_unverified_context()
                    with context.wrap_socket(plain, server_hostname='localhost') as tls:
                        pin = hashlib.sha256(tls.getpeercert(binary_form=True)).hexdigest()
                defines = work / 'defines.json'
                defines.write_text(json.dumps({
                    'QA_API_BASE': 'https://localhost:4840/api/v1',
                    'QA_CERT_SHA256': pin,
                    'QA_PASSWORD': stack.password,
                }))
                defines.chmod(0o600)
                run_owned([
                    'flutter', 'drive', '--driver', 'test_driver/guild_identity_qa.dart',
                    '--target', 'integration_test/guild_identity_qa_test.dart', '-d', device,
                    '--dart-define-from-file', str(defines),
                ], cwd=root / 'clients/flutter',
                    env=dict(os.environ, BOOHTACORD_NATIVE_CAPTURE_DIR=str(destination)),
                    timeout=1200)
            finally:
                stack.close()
    finally:
        if args.platform == 'android':
            subprocess.run(
                ['adb', '-s', device, 'reverse', '--remove', 'tcp:4840'], check=True,
            )
    report = json.loads((destination / 'scenario.json').read_text())
    report.update(
        **identity,
        owned_resources_removed=True,
        started_at=started,
        completed_at=datetime.now(timezone.utc).isoformat(),
        build_mode='debug',
        app='real Flutter app with integration_test binding',
        screenshots={path.name: hashlib.sha256(path.read_bytes()).hexdigest()
                     for path in destination.glob('*.png')},
    )
    (destination / 'runtime.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
    if report.get('status') != 'PASS':
        raise RuntimeError('Native guild identity acceptance did not pass')
    print('278 native supplemental: PASS')


if __name__ == '__main__':
    main()
