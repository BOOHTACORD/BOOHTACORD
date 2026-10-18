"""Actual two-browser signed rollback on one isolated nested Docker daemon."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import time
from .daemon import Daemon
from .evidence import validate
from tools.qa.local_features.process import stop_group


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--ci-proof', type=Path, required=True,
                        help='Observed successful GitHub gate results for the two exact heads; see README')
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[3]
    proof = json.loads(args.ci_proof.read_text())
    for role in ('current', 'previous'):
        if not re.fullmatch('[0-9a-f]{40}', proof[role]['head']):
            raise ValueError('Exact CI source heads are required')
    destination = root / '.out/issue60/runtime'
    if destination.exists():
        destination.rename(destination.parent / ('attempt-' + str(time.time_ns())))
    destination.mkdir(parents=True)
    report = {'issue': 60, 'status': 'RUNNING', 'source_base': subprocess.check_output(
        ['git', 'rev-parse', 'HEAD'], cwd=root, text=True).strip(), 'ci_proof': proof}
    node = None
    stack = None
    source_files = [p for p in Path(__file__).parent.iterdir() if p.suffix in ('.py', '.mjs') or p.name == 'Dockerfile']
    source_hashes = lambda: {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in source_files}
    report['harness_sha256'] = source_hashes()
    def save():
        (destination / 'run.json').write_text(json.dumps(report, indent=2) + '\n')
    save()
    try:
        with tempfile.TemporaryDirectory(prefix='qa60-', dir=root / '.out') as temporary:
            work = Path(temporary)
            for role in ('current', 'previous'):
                source = work / role
                subprocess.run(['git', 'clone', '--shared', '--no-checkout', str(root), str(source)], check=True, capture_output=True)
                subprocess.run(['git', 'checkout', '--detach', proof[role]['head']], cwd=source, check=True, capture_output=True)
            (work / 'ci-proof.json').write_text(json.dumps(proof))
            stack = Daemon(root, work)
            try:
                with (destination / 'prepare-private.log').open('wb') as log:
                    stack.start()
                    (destination / 'owner.json').write_text(json.dumps({'owner': stack.owner, 'work': str(work), 'resources': stack.resources}))
                    print('QA60_PHASE build genuine attested QA bundles', flush=True)
                    stack.execute('python3', '/qa-tools/controller.py', 'prepare', stdout=log, stderr=subprocess.STDOUT, timeout=3600)
                stack.reclaim()
                report['environment'] = json.loads((work / 'environment.json').read_text())
                print('QA60_PHASE two actual browser observers', flush=True)
                with (destination / 'browser-runtime.log').open('wb') as log:
                    node = subprocess.Popen(['node', str(root / 'tools/qa/compatible_rollback/scenario.mjs')],
                        cwd=root, env=dict(os.environ, QA60_WORK=str(work), QA60_OUTPUT=str(destination)),
                        stdout=log, stderr=subprocess.STDOUT, start_new_session=True)
                    deadline = time.monotonic() + 90
                    while not (work / 'browser-ready.json').exists():
                        if node.poll() is not None or (work / 'browser-failure.json').exists():
                            raise RuntimeError('Actual browser dataset preparation failed')
                        if time.monotonic() > deadline:
                            raise TimeoutError('Actual browser preparation exceeded its budget')
                        time.sleep(.2)
                    print('QA60_PHASE canonical signed rollback and restore', flush=True)
                    with (destination / 'controller-private.log').open('wb') as controller:
                        stack.execute('python3', '/qa-tools/controller.py', 'rehearse', stdout=controller, stderr=subprocess.STDOUT, timeout=900)
                    if node.wait(timeout=20):
                        raise RuntimeError('Actual browser observers failed')
                receipt = json.loads((work / 'runtime.json').read_text())
                validate(receipt)
                if source_hashes() != report['harness_sha256']:
                    raise RuntimeError('Harness source changed during the accepted run')
                report['acceptance'] = receipt
                shutil.copyfile(work / 'runtime.json', destination / 'acceptance.json')
                report['images'] = []
                for directory in (work / 'releases').iterdir():
                    if (directory / 'manifest.json').is_file():
                        manifest = json.loads((directory / 'manifest.json').read_text())
                        report['images'].append({'revision': manifest['source_revision'], 'components': manifest['components'],
                                                 'compatibility': manifest['compatibility'],
                                                 'manifest_sha256': hashlib.sha256((directory / 'manifest.json').read_bytes()).hexdigest()})
                report['captures'] = [{'file': p.name, 'sha256': hashlib.sha256(p.read_bytes()).hexdigest()} for p in sorted(destination.glob('*.png'))]
                report['status'] = 'PASS'
            finally:
                if node is not None and node.poll() is None:
                    stop_group(node)
                stack.close()
                report['owned_resources_removed'] = not stack.resources
    except BaseException as error:
        report['status'] = 'FAIL'
        report['error_type'] = type(error).__name__
        from .diagnostics import diagnose, public_guards
        messages = public_guards(root)
        report['diagnostics'] = {name: diagnose(path.read_text(errors='replace'), messages)
                                 for name in ('prepare-private', 'controller-private')
                                 if (path := destination / (name + '.log')).is_file()}
        raise
    finally:
        save()


if __name__ == '__main__':
    main()
