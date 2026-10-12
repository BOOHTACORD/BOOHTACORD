"""Actual integrated Web admin and dialog cases; private disposable fixtures only."""
import hashlib
import json
import os
import subprocess
import tempfile
import time
from pathlib import Path
from .stack import Stack, WEB_PORTS


def initialize_requested_widths(base, widths, metadata):
    if not widths or len(set(widths)) != len(widths) or any(w not in (320,393,1440) for w in widths):
        raise ValueError('Unregistered QA width matrix')
    stamp=str(time.time_ns())
    for width in widths:
        destination=base/str(width)
        destination.mkdir(parents=True,exist_ok=True)
        previous=base/'previous-harness-runs'/str(width)/stamp
        files=[p for p in destination.iterdir() if p.is_file()]
        if files:
            previous.mkdir(parents=True)
            for path in files:path.rename(previous/path.name)
        (destination/'runtime.json').write_text(json.dumps(dict(metadata,status='NOT_RUN',reason='Requested matrix entry has not started'))+'\n')


def main():
    root = Path(__file__).resolve().parents[3]
    os.environ['DOCKER_CONTEXT'] = 'colima-boohtacord-qa'
    candidate = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=root, text=True).strip()
    widths=list(map(int,os.environ.get('QA_WIDTHS','393,1440').split(',')))
    src=root/'clients/web/src'
    web_sources={str(p.relative_to(src)):hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(src.rglob('*')) if p.is_file() and p.suffix in ('.vue','.ts','.css')}
    metadata={'candidate':candidate,'web_source_manifest_sha256':hashlib.sha256(json.dumps(web_sources,sort_keys=True).encode()).hexdigest()}
    base=root/'.out/qa295298-20261012'
    initialize_requested_widths(base,widths,metadata)
    for width in widths:
        destination=base/str(width)
        report = dict(metadata,status='RUNNING')
        (destination/'runtime.json').write_text(json.dumps(report)+'\n')
        cleaned = False
        try:
            with tempfile.TemporaryDirectory(prefix='qa295298-', dir=root/'.out') as temporary:
                work = Path(temporary)
                stack = Stack(root, work,ports=WEB_PORTS)
                try:
                    stack.start()
                    metadata["web_artifact_manifest_sha256"]=stack.web_artifact_sha256
                    private = work/'input.json'
                    private.write_text(json.dumps({'password': stack.password, 'width': width, 'directory': str(destination)}))
                    private.chmod(0o600)
                    env = dict(os.environ, QA_ORIGIN=f'https://localhost:{WEB_PORTS.https}', QA_INPUT=str(private), QA_RESULT=str(destination/'results.json'), QA_DB_OWNER=stack.owner)
                    subprocess.run(['node', str(root/'tools/qa/admin_dialogs/scenario.mjs')], cwd=root, env=env, check=True, timeout=360)
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
            report.update(**metadata, owned_resources_removed=cleaned, screenshots={p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in destination.glob('*.png')})
            (destination/'runtime.json').write_text(json.dumps(report, indent=2)+'\n')
        print(f'#295/#298 width {width}: observed Web PASS; physical acceptance still NOT_RUN', flush=True)


if __name__ == '__main__': main()
