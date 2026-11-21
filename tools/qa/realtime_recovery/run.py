"""Run R1 against the owned real API/PostgreSQL/LiveKit and production Web app."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import tempfile
import time
from .control import api_control
from .config import ORIGIN
from .stack import Stack
from tools.qa.local_features.source_identity import source_identity, source_stability


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--node', default='node', help='Native Linux Node executable')
    parser.add_argument('--output', default='.out/issue689-r1-' + time.strftime('%Y%m%d-%H%M%S'))
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[3]
    output = (root / args.output).resolve()
    if not output.is_relative_to(root / '.out'):
        raise ValueError('Runtime output must stay inside checkout .out')
    output.mkdir(parents=True, exist_ok=False)
    identity = source_identity(root)
    environment = dict(os.environ, VITE_PUBLIC_ORIGIN=ORIGIN, SOURCE_REVISION=identity.split()[0])
    command = ['npm', 'run', 'build']
    with (output / 'build.log').open('w') as log:
        subprocess.run(command, cwd=root / 'clients/web', env=environment, check=True,
                       stdout=log, stderr=subprocess.STDOUT, timeout=180)
    dist = root / 'clients/web/dist'
    built = {str(p.relative_to(dist)): hashlib.sha256(p.read_bytes()).hexdigest()
             for p in [dist / 'index.html', *sorted((dist / 'assets').glob('index-*'))]}
    with tempfile.TemporaryDirectory(prefix='r1-', dir=root / '.out') as temporary:
        work = Path(temporary)
        stack = Stack(root, work)
        try:
            stack.start()
            private = work / 'input.json'
            with api_control(stack) as control:
                private.write_text(json.dumps(dict(password=stack.password, directory=str(output), control=control)))
                private.chmod(0o600)
                environment = dict(os.environ, QA_ORIGIN=ORIGIN, QA_INPUT=str(private))
                subprocess.run([args.node, str(Path(__file__).with_name('scenario.mjs'))],
                               cwd=root, env=environment, check=True, timeout=240)
            report = json.loads((output / 'scenario.json').read_text())
            report['source_before'], report['source_after'] = identity, source_identity(root)
            report['production_web_files'] = built
            report['source_stability'] = source_stability(identity, report['source_after'])
            if report['source_stability']['status'] != 'PASS':
                raise ValueError('Source changed during the runtime observation')
            (output / 'runtime.json').write_text(json.dumps(report, indent=2) + '\n')
            print('R1_REAL_STACK_PASS', flush=True)
        finally:
            stack.close()


if __name__ == '__main__':
    main()
