"""Actual browser/API acceptance for #264; synthetic local data only."""
import hashlib
import json
import os
import subprocess
import tempfile
from pathlib import Path
from tools.qa.local_features.stack import Stack


def main():
    root = Path(__file__).resolve().parents[3]
    os.environ['DOCKER_CONTEXT'] = 'colima-boohtacord-qa'
    destination = root/'.out/qa264-20261012'
    destination.mkdir(parents=True, exist_ok=True)
    widths = [int(value) for value in os.environ.get('QA_WIDTHS','1440,393').split(',')]
    if not widths or any(width not in (1440,393) for width in widths):
        raise ValueError('Only registered desktop/mobile QA widths are allowed')
    for width in widths:
        directory = destination/str(width)
        directory.mkdir(exist_ok=True)
        with tempfile.TemporaryDirectory(prefix='qa264-', dir=root/'.out') as temporary:
            work = Path(temporary)
            stack = Stack(root, work)
            try:
                stack.start()
                inputs = work/'input.json'
                inputs.write_text(json.dumps({'password':stack.password, 'width':width, 'directory':str(directory)}))
                inputs.chmod(0o600)
                env = dict(os.environ, QA_ORIGIN='https://localhost:4810', QA_INPUT=str(inputs), QA_RESULT=str(directory/'results.json'), QA_DB_OWNER=stack.owner)
                subprocess.run(['node', str(root/'tools/qa/mentions_inbox/scenario.mjs')], cwd=root, env=env, check=True, timeout=420)
            finally:
                stack.close()
        report = json.loads((directory/'results.json').read_text())
        report.update(candidate=subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip(), owned_resources_removed=True,
                      screenshots={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in directory.glob('*.png')})
        (directory/'results.json').write_text(json.dumps(report,indent=2)+'\n')
        print(f'#264 width {width}: PASS, owned services removed', flush=True)


if __name__ == '__main__':
    main()
