"""Actual built Web PTT through an independent receiving browser and owned SFU."""
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
from .control import media_control
from .signal import write_signal


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', default='.out/ptt-'+time.strftime('%Y%m%d-%H%M%S'))
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[3]
    destination = (root/args.output).resolve()
    if not destination.is_relative_to(root/'.out'):
        raise ValueError('Owned output required')
    destination.mkdir(parents=True, exist_ok=False)
    source = source_identity(root)
    result = dict(status='FAIL', source_before=source, platform='web')
    with (destination/'build.log').open('w', encoding='utf-8') as log:
        subprocess.run(['npm.cmd' if os.name == 'nt' else 'npm', 'run', 'build'],
            cwd=root/'clients/web', check=True, timeout=240, stdout=log, stderr=subprocess.STDOUT,
            env=dict(os.environ, VITE_PUBLIC_ORIGIN='https://localhost:4910', SOURCE_REVISION=source.split()[0]))
    with tempfile.TemporaryDirectory(prefix='ptt-', dir=root/'.out') as temporary:
        work = Path(temporary); stack = Stack(root, work, web=True)
        try:
            stack.start(); signal = work/'signal.wav'; write_signal(signal)
            result['synthetic_signal_sha256'] = hashlib.sha256(signal.read_bytes()).hexdigest()
            with media_control(stack) as control:
                private = work/'private.json'
                private.write_text(json.dumps(dict(password=stack.password, control=control,
                    directory=str(destination), signal=str(signal))), encoding='utf-8'); private.chmod(0o600)
                with (destination/'private-run.log').open('w', encoding='utf-8') as log:
                    subprocess.run(['node', str(Path(__file__).with_name('scenario.mjs'))], cwd=root,
                        env=dict(os.environ, QA_ORIGIN='https://localhost:4910', QA_INPUT=str(private)),
                        check=True, timeout=600, stdout=log, stderr=subprocess.STDOUT)
            result['scenario'] = json.loads((destination/'scenario.json').read_text())
            if result['scenario']['status'] != 'PASS':
                raise ValueError('PTT acceptance did not pass')
            result['status'] = 'PASS'
        finally:
            stack.close(); result['owned_resources_removed'] = True
            result['source_after'] = source_identity(root)
            result['source_stability'] = source_stability(source, result['source_after'])
            if result['source_stability']['status'] != 'PASS': result['status'] = 'BLOCKED'
            result['bundle_sha256'] = hashlib.sha256((root/'clients/web/dist/index.html').read_bytes()).hexdigest()
            (destination/'runtime.json').write_text(json.dumps(result, indent=2)+'\n', encoding='utf-8')
    if result['status'] != 'PASS': raise SystemExit('PTT source stability failed')
    print('PTT_WEB_PASS')


if __name__ == '__main__': main()
