"""Actual production Web clients and disposable API/PostgreSQL/LiveKit for #247."""
import hashlib
import json
import os
import platform
import subprocess
import tempfile
from pathlib import Path
from .stack import Stack
from .native import archive_previous, source_manifest, digest
from datetime import datetime, timezone


def main():
    root = Path(__file__).resolve().parents[3]
    candidate = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=root, text=True).strip()
    os.environ['DOCKER_CONTEXT'] = 'colima-boohtacord-qa'
    destination = root/'.out/qa247-20261012/web'
    destination.mkdir(parents=True, exist_ok=True)
    archive_previous(destination)
    (destination/'results.json').unlink(missing_ok=True)
    result={'issue':247,'status':'RUNNING','phase':'stack startup','runtime_completed':False,'candidate':candidate,
            'qa_handler_sha256':{name:digest(root/'tools/qa/mini_player'/name) for name in ('run.py','bridge.py','scenario.mjs')},
            'web_source_manifest':source_manifest(root/'clients/web/src')[0],
            'web_build_manifest':source_manifest(root/'.out/qa247-build')[0],
            'started_at':datetime.now(timezone.utc).isoformat()}
    receipt=destination/'runtime.json'
    receipt.write_text(json.dumps(result,indent=2)+'\n')
    with tempfile.TemporaryDirectory(prefix='qa247-', dir=root/'.out') as temporary:
        stack = Stack(root, Path(temporary))
        try:
            stack.start()
            inputs = Path(temporary)/'input.json'
            inputs.write_text(json.dumps({'password': stack.password, 'directory': str(destination), 'owner': stack.owner}))
            inputs.chmod(0o600)
            # This path contains only disposable credentials. Do not print contents.
            (root/'.out/qa247-20261012/active-input-path').write_text(str(inputs))
            env = dict(os.environ, QA_ORIGIN='https://localhost:4830', QA_INPUT=str(inputs), QA_RESULT=str(destination/'results.json'))
            result['phase']='actual Web runtime';receipt.write_text(json.dumps(result,indent=2)+'\n')
            subprocess.run(['node', str(root/'tools/qa/mini_player/scenario.mjs')], cwd=root, env=env, check=True, timeout=7200)
            result['runtime_completed']=True
        except Exception as error:
            result.update(status='FAIL',error_type=type(error).__name__,error_phase=result['phase'])
            raise
        finally:
            stack.close()
            (root/'.out/qa247-20261012/active-input-path').unlink(missing_ok=True)
            result_path = destination/'results.json'
            if result_path.exists():
                outcome=json.loads(result_path.read_text())
                if not result['runtime_completed']:outcome['status']='FAIL'
                result.update(outcome)
                result.update(candidate=candidate, host=platform.platform(), owned_resources_removed=True,
                              screenshots={p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in destination.glob('*.png')})
                result_path.write_text(json.dumps(result, indent=2)+'\n')
            elif result.get('status')=='RUNNING':result.update(status='FAIL',error_phase='missing scenario')
            receipt.write_text(json.dumps(result,indent=2)+'\n')
    if result.get('status') != 'PASS':
        raise RuntimeError('#247 browser acceptance incomplete: '+str(result.get('failed_at')))
    print('#247 actual Web scenarios PASS; owned services removed', flush=True)


if __name__ == '__main__':
    main()
