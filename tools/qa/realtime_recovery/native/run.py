"""Build and run native R1 with actual API/SFU and source-bound finite evidence."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import socket
import ssl
import subprocess
import tempfile
import time
from tools.qa.local_features.source_identity import source_identity, source_stability
from tools.qa.realtime_recovery.control import api_control
from .device import device_ports
from .stack import Stack
from .process import run_native
from .prepare import remove_generated


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--platform', required=True, choices=('windows', 'android'))
    parser.add_argument('--device', required=True)
    parser.add_argument('--flutter', default='flutter')
    parser.add_argument('--adb', default='adb')
    parser.add_argument('--output', default='.out/r1-native-'+time.strftime('%Y%m%d-%H%M%S'))
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[4]
    destination = (root/args.output).resolve()
    if not destination.is_relative_to(root/'.out'): raise ValueError('Output outside owned .out')
    destination.mkdir(parents=True, exist_ok=False)
    remove_generated(root)
    if args.platform == 'windows':
        from tools.build.desktop_updater.sdk import prepare
        prepare('windows')
    source = source_identity(root)
    result = dict(status='FAIL', platform=args.platform, source_before=source,
                  physical_android=False, storage_adapters='test-only preferences and secure storage')
    with tempfile.TemporaryDirectory(prefix='r1-native-', dir=root/'.out') as directory:
        work = Path(directory); stack = Stack(root, work)
        try:
            stack.start()
            with socket.create_connection(('127.0.0.1', 4910), timeout=5) as plain:
                with ssl._create_unverified_context().wrap_socket(plain, server_hostname='localhost') as secure:
                    pin = hashlib.sha256(secure.getpeercert(binary_form=True)).hexdigest()
            with api_control(stack) as control, device_ports(args.platform, args.device, args.adb,
                                                            [4910, 4920, 4981, int(control['url'].split(':')[2].split('/')[0])]):
                defines = work/'defines.json'
                defines.write_text(json.dumps(dict(QA_API_BASE='https://localhost:4910/api/v1',
                    QA_CERT_SHA256=pin, QA_PASSWORD=stack.password,
                    QA_CONTROL_URL=control['url'], QA_CONTROL_TOKEN=control['token'])), encoding='utf-8')
                defines.chmod(0o600)
                with (destination/'private-run.log').open('w', encoding='utf-8') as log:
                    run_native([args.flutter, 'drive', *(['--no-pub'] if args.platform == 'windows' else []),
                        '--driver', 'test_driver/r1_native.dart',
                        '--target', 'integration_test/issue689_r1_native_test.dart', '-d', args.device,
                        '--dart-define-from-file', str(defines)], cwd=root/'clients/flutter',
                        env=dict(os.environ, BOOHTACORD_NATIVE_CAPTURE_DIR=str(destination)),
                        stdout=log, stderr=subprocess.STDOUT)
            result['scenario'] = json.loads((destination/'scenario.json').read_text())
            if result['scenario']['status'] != 'PASS': raise ValueError('Native scenario did not pass')
            result['status'] = 'PASS'
        except Exception as error:
            result['failure_type'] = type(error).__name__
            raise
        finally:
            stack.close()
            result['owned_resources_removed'] = True
            remove_generated(root)
            result['source_after'] = source_identity(root)
            result['source_stability'] = source_stability(source, result['source_after'])
            if result['source_stability']['status'] != 'PASS': result['status'] = 'BLOCKED'
            (destination/'runtime.json').write_text(json.dumps(result, indent=2)+'\n', encoding='utf-8')
    if result['status'] != 'PASS': raise SystemExit('Native source stability failed')
    print('R1_NATIVE_PASS '+args.platform)


if __name__ == '__main__': main()
