"""Actual integrated Web message actions; private disposable fixtures only."""
import hashlib
import json
import os
import subprocess
import tempfile
from pathlib import Path
from .stack import Stack


def main():
    root = Path(__file__).resolve().parents[3]
    os.environ['DOCKER_CONTEXT'] = 'colima-boohtacord-qa'
    candidate = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=root, text=True).strip()
    for width in map(int, os.environ.get('QA_WIDTHS', '320,393,1440').split(',')):
        if width not in (320, 393, 1440):
            raise ValueError('Unregistered QA width')
        destination = root/'.out/qa293-20261012'/str(width)
        destination.mkdir(parents=True, exist_ok=True)
        for old in [destination/'results.json', *destination.glob('*.png')]:
            if old.exists(): old.unlink()
        report = {'status': 'RUNNING', 'candidate': candidate}
        (destination/'runtime.json').write_text(json.dumps(report)+'\n')
        cleaned = False
        try:
            with tempfile.TemporaryDirectory(prefix='qa293-', dir=root/'.out') as temporary:
                work = Path(temporary)
                stack = Stack(root, work)
                try:
                    stack.start()
                    private = work/'input.json'
                    private.write_text(json.dumps({'password': stack.password, 'width': width, 'directory': str(destination)}))
                    private.chmod(0o600)
                    env = dict(os.environ, QA_ORIGIN='https://localhost:4810', QA_INPUT=str(private), QA_RESULT=str(destination/'results.json'), QA_DB_OWNER=stack.owner)
                    subprocess.run(['node', str(root/'tools/qa/message_actions/scenario.mjs')], cwd=root, env=env, check=True, timeout=360)
                    report = json.loads((destination/'results.json').read_text())
                    if report.get('status') != 'PASS': raise RuntimeError('Scenario did not pass')
                finally:
                    stack.close()
                    cleaned = True
        except Exception as failure:
            if (destination/'results.json').exists(): report = json.loads((destination/'results.json').read_text())
            report.update(status='FAIL', runner_failure_type=type(failure).__name__)
            raise
        finally:
            report.update(candidate=candidate, owned_resources_removed=cleaned, screenshots={p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in destination.glob('*.png')})
            (destination/'runtime.json').write_text(json.dumps(report, indent=2)+'\n')
        print(f'#293 width {width}: observed Web PASS; physical acceptance still NOT_RUN', flush=True)


if __name__ == '__main__': main()
