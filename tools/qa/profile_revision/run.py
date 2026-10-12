"""Profile revision acceptance on the dedicated Android/iOS QA runtime."""
import argparse
import hashlib
import json
import os
import socket
import ssl
import subprocess
import tempfile
from pathlib import Path
from tools.qa.local_features.native import verify_device, reversed_ports
from tools.qa.local_features.stack import Stack
from tools.qa.local_features.process import run_owned
from contextlib import nullcontext


def prepare_attempt(destination):
    destination.mkdir(parents=True, exist_ok=True)
    for artifact in [destination/'scenario.json', *destination.glob('*.png')]:
        if artifact.exists(): artifact.unlink()
    (destination/'runtime.json').write_text(json.dumps({'status': 'RUNNING'})+'\n')


def scenario_passed(report):
    return isinstance(report, dict) and report.get('status') == 'PASS'


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--platform', required=True, choices=['android', 'ios'])
    parser.add_argument('--device', required=True)
    args = parser.parse_args()
    sdk = '/opt/homebrew/share/android-commandlinetools'
    os.environ.setdefault('ANDROID_HOME', sdk)
    os.environ.setdefault('ANDROID_SDK_ROOT', sdk)
    os.environ.setdefault('JAVA_HOME', '/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home')
    os.environ['PATH'] = sdk+'/platform-tools:/opt/homebrew/bin:'+os.environ.get('PATH', '')
    os.environ['DOCKER_CONTEXT'] = 'colima-boohtacord-qa'
    root = Path(__file__).resolve().parents[3]
    candidate = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=root, text=True).strip()
    destination = root/'.out/qa276-20261012'/args.platform
    prepare_attempt(destination)
    report = {'status': 'RUNNING'}
    resources_removed = True
    try:
        verify_device(args.platform, args.device)
        with reversed_ports(args.device) if args.platform == 'android' else nullcontext():
            with tempfile.TemporaryDirectory(prefix='profile-revision-qa-', dir=root/'.out') as temporary:
                work = Path(temporary)
                stack = Stack(root, work)
                resources_removed = False
                try:
                    stack.start()
                    context = ssl._create_unverified_context()
                    with socket.create_connection(('127.0.0.1', 4810), timeout=5) as plain:
                        with context.wrap_socket(plain, server_hostname='localhost') as secure:
                            pin = hashlib.sha256(secure.getpeercert(binary_form=True)).hexdigest()
                    defines = work/'defines.json'
                    defines.write_text(json.dumps({'QA_API_BASE': 'https://localhost:4810/api/v1', 'QA_CERT_SHA256': pin, 'QA_PASSWORD': stack.password}))
                    defines.chmod(0o600)
                    run_owned(['flutter', 'drive', '--driver', 'test_driver/profile_revision_qa.dart', '--target',
                               'integration_test/profile_revision_qa_test.dart', '-d', args.device,
                               '--dart-define-from-file', str(defines)], cwd=root/'clients/flutter',
                              env=dict(os.environ, BOOHTACORD_NATIVE_CAPTURE_DIR=str(destination)), timeout=1200)
                    report = json.loads((destination/'scenario.json').read_text())
                    assert scenario_passed(report), 'Native acceptance did not pass'
                finally:
                    stack.close()
                    resources_removed = True
    except Exception as failure:
        scenario = destination/'scenario.json'
        if scenario.exists():
            try: report = json.loads(scenario.read_text())
            except (ValueError, OSError): report = {}
        report.update(status='FAIL', runner_failure_type=type(failure).__name__)
        raise
    finally:
        report.update(candidate=candidate, owned_resources_removed=resources_removed, physical_device=False,
                      screenshots={p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in destination.glob('*.png')})
        (destination/'runtime.json').write_text(json.dumps(report, indent=2)+'\n')
    print('#276 '+args.platform+': PASS; owned resources removed', flush=True)


if __name__ == '__main__':
    main()
