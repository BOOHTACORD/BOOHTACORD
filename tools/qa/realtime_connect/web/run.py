"""Build the actual Web app and accept bounded recovery with real transport faults."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import tempfile
import time
from tools.qa.local_features.source_identity import source_identity, source_stability
from tools.qa.realtime_connect.fixture.stack import Stack


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', default='.out/r2-web-'+time.strftime('%Y%m%d-%H%M%S'))
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[4]
    destination = (root/args.output).resolve()
    if not destination.is_relative_to(root/'.out'): raise ValueError('Output outside owned .out')
    destination.mkdir(parents=True, exist_ok=False)
    source = source_identity(root)
    result = dict(status='FAIL', source_before=source, platform='web')
    with (destination/'build.log').open('w', encoding='utf-8') as log:
        subprocess.run(['npm.cmd' if os.name == 'nt' else 'npm', 'run', 'build'],
            cwd=root/'clients/web', check=True, timeout=240, stdout=log, stderr=subprocess.STDOUT,
            env=dict(os.environ, VITE_PUBLIC_ORIGIN='https://localhost:4910', SOURCE_REVISION=source.split()[0]))
    with tempfile.TemporaryDirectory(prefix='r2-web-', dir=root/'.out') as temporary:
        stack = Stack(root, Path(temporary), web=True)
        try:
            stack.start()
            private = Path(temporary)/'private.json'
            private.write_text(json.dumps(dict(password=stack.password, token=stack.fault_token,
                directory=str(destination))), encoding='utf-8'); private.chmod(0o600)
            with (destination/'private-run.log').open('w', encoding='utf-8') as log:
                subprocess.run(['node', str(Path(__file__).with_name('scenario.mjs'))], cwd=root,
                    env=dict(os.environ, QA_ORIGIN='https://localhost:4910', QA_INPUT=str(private)),
                    check=True, timeout=420, stdout=log, stderr=subprocess.STDOUT)
            result['scenario'] = json.loads((destination/'scenario.json').read_text())
            if result['scenario']['status'] != 'PASS': raise ValueError('Web R2 did not pass')
            result['status'] = 'PASS'
        finally:
            stack.close(); result['owned_resources_removed'] = True
            result['source_after'] = source_identity(root)
            result['source_stability'] = source_stability(source, result['source_after'])
            if result['source_stability']['status'] != 'PASS': result['status'] = 'BLOCKED'
            result['bundle_sha256'] = hashlib.sha256((root/'clients/web/dist/index.html').read_bytes()).hexdigest()
            (destination/'runtime.json').write_text(json.dumps(result, indent=2)+'\n', encoding='utf-8')
    if result['status'] != 'PASS': raise SystemExit('R2 Web acceptance failed')
    print('R2_WEB_PASS')


if __name__ == '__main__': main()
