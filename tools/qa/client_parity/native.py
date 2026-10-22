"""Client parity smoke on a dedicated QA runtime, using actual Go API and cookies."""
import argparse
from contextlib import nullcontext
import hashlib
import json
import os
from pathlib import Path
import socket
import ssl
import subprocess
import tempfile
from tools.qa.local_features.stack import Stack
from tools.qa.local_features.native import verify_device, reversed_ports
from tools.qa.local_features.process import run_owned
from tools.qa.client_lifecycle.services import run, output

ROOT = Path(__file__).resolve().parents[3]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--platform', required=True, choices=['android', 'ios'])
    parser.add_argument('--device', required=True)
    parser.add_argument('--output', required=True)
    args = parser.parse_args()
    destination = Path(args.output).resolve()
    if not destination.is_relative_to(ROOT / '.out'):
        parser.error('Use a fresh directory under this checkout’s .out')
    destination.mkdir(parents=True, exist_ok=False)
    verify_device(args.platform, args.device)
    scenario = ROOT / 'clients/flutter/integration_test/client_parity_qa_test.dart'
    report = {'status': 'FAIL', 'platform': args.platform, 'mocks': False,
              'owned_resources_removed': False, 'physical': False, 'capture_audio_background': 'NOT_RUN', 'scope': 'replay, social hints, reachable admin telemetry', 'source': output('git', '-C', str(ROOT), 'rev-parse', 'HEAD'),
              'working_diff_sha256': hashlib.sha256(subprocess.check_output(['git', 'diff', 'HEAD', '--binary'], cwd=ROOT)).hexdigest(),
              'scenario_sha256': hashlib.sha256(scenario.read_bytes()).hexdigest()}
    try:
        with reversed_ports(args.device) if args.platform == 'android' else nullcontext():
            with tempfile.TemporaryDirectory(prefix='native-parity-', dir=ROOT / '.out') as temporary:
                work = Path(temporary)
                stack = Stack(ROOT, work)
                try:
                    stack.start()
                    run('docker', 'exec', stack.owner + '-db', 'psql', '-U', 'qa', '-d', 'qa', '-v', 'ON_ERROR_STOP=1', '-c', "INSERT INTO users(id,login,display_name,password_hash,role) SELECT gen_random_uuid(),'qa_peer','QA Peer',password_hash,'MEMBER' FROM users WHERE login='qa_admin'", stdout=subprocess.DEVNULL)
                    with socket.create_connection(('127.0.0.1', 4810), timeout=5) as plain:
                        with ssl._create_unverified_context().wrap_socket(plain, server_hostname='localhost') as secure:
                            pin = hashlib.sha256(secure.getpeercert(binary_form=True)).hexdigest()
                    defines = work / 'defines.json'
                    defines.write_text(json.dumps({'QA_API_BASE': 'https://localhost:4810/api/v1',
                                                   'QA_CERT_SHA256': pin, 'QA_PASSWORD': stack.password}))
                    defines.chmod(0o600)
                    run_owned(['flutter', 'drive', '--driver', 'test_driver/local_qa.dart',
                               '--target', 'integration_test/client_parity_qa_test.dart', '-d', args.device,
                               '--dart-define-from-file', str(defines)], cwd=ROOT / 'clients/flutter',
                              env=dict(os.environ, BOOHTACORD_NATIVE_CAPTURE_DIR=str(destination)), timeout=600)
                finally:
                    stack.close()
                    report['owned_resources_removed'] = True
                report['owned_resources_removed'] = True
                report['status'] = 'PASS'
    finally:
        (destination / 'runtime.json').write_text(json.dumps(report, indent=2) + '\n')
        print('Native client parity ' + args.platform + ': ' + report['status'], flush=True)
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
