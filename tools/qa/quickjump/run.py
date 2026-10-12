"""Isolated actual Web quick-jump QA; no production mutations."""
import hashlib
import json
import os
import subprocess
import tempfile
import time
from pathlib import Path
from .stack import Stack


def main():
    root = Path(__file__).resolve().parents[3]
    os.environ['DOCKER_CONTEXT'] = 'colima-boohtacord-qa'
    destination = root/'.out/qa283-20261012'
    destination.mkdir(parents=True, exist_ok=True)
    for width in [int(v) for v in os.environ.get('QA_WIDTHS','1440,393').split(',')]:
        output = destination/str(width)
        output.mkdir(exist_ok=True)
        previous=destination/'previous-harness-runs'/str(width)/str(time.time_ns())
        if any(output.glob('*.png')):
            previous.mkdir(parents=True)
            for old in output.glob('*.png'): old.rename(previous/old.name)
        with tempfile.TemporaryDirectory(prefix='qa283-', dir=root/'.out') as temporary:
            stack = Stack(root,Path(temporary))
            try:
                stack.start()
                inputs=Path(temporary)/'input.json'
                inputs.write_text(json.dumps({'password':stack.password,'width':width,'directory':str(output)}))
                inputs.chmod(0o600)
                env=dict(os.environ, QA_ORIGIN='https://localhost:4830', QA_INPUT=str(inputs), QA_RESULT=str(output/'results.json'),QA_DB_OWNER=stack.owner)
                subprocess.run(['node', str(root/'tools/qa/quickjump/scenario.mjs')],cwd=root,env=env,check=True,timeout=420)
            finally:
                stack.close()
        result=json.loads((output/'results.json').read_text())
        result.update(candidate=subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip(),owned_resources_removed=True,screenshots={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in output.glob('*.png')})
        (output/'results.json').write_text(json.dumps(result,indent=2)+'\n')
        print(f'#283 width{width}: runtime finished; owned services removed',flush=True)


if __name__=='__main__':
    main()
