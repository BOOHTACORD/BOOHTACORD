"""Built-Web history acceptance with fresh owned database/API and finite synthetic data."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import tempfile
from tools.qa.client_lifecycle.services import output, run
from tools.qa.local_features.stack import Stack


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--width', type=int, choices=[1440, 393], action='append')
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[3]
    destination = root/'.out/history-edit-retention'
    destination.mkdir(parents=True, exist_ok=False)
    report = {'status': 'FAIL', 'source_revision': output('git', 'rev-parse', 'HEAD'),
              'source_dirty': bool(output('git', 'status', '--porcelain')),
              'mocks': False, 'physical_acceptance': 'NOT_RUN', 'widths': []}
    sources = [*root.glob('tools/qa/history_edit_retention/*.*'),
               root/'clients/web/src/conversation/history_window/use.ts',
               root/'clients/web/src/conversation/history_window/measurement_delivery/frame.ts']
    fingerprints = lambda: {str(path.relative_to(root)): hashlib.sha256(path.read_bytes()).hexdigest()
                            for path in sources}
    report['source_files'] = fingerprints()
    run('npm', 'run', 'build', cwd=root/'clients/web', stdout=subprocess.DEVNULL,
        env=dict(os.environ, VITE_PUBLIC_ORIGIN='https://localhost:4810'))
    with tempfile.TemporaryDirectory(prefix='qa-history-', dir=root/'.out') as temporary:
        work = Path(temporary)
        stack = Stack(root, work)
        try:
            stack.start()
            for width in args.width or [1440, 393]:
                target = destination/str(width)
                target.mkdir()
                inputs = work/'input.json'
                inputs.write_text(json.dumps({'password': stack.password, 'directory': str(target),
                    'viewport': {'width': width}, 'history_matrix': width == 1440}))
                inputs.chmod(0o600)
                run('node', str(root/'tools/qa/history_edit_retention/scenario.mjs'), cwd=root,
                    env=dict(os.environ, QA_INPUT=str(inputs), QA_DB_OWNER=stack.owner,
                             QA_ORIGIN='https://localhost:4810'))
                result = json.loads((target/'browser.json').read_text())
                assert result['status'] == 'PASS'
                report['widths'].append(result)
            report['status'] = 'PASS'
        finally:
            stack.close()
            remaining = output('docker', 'ps', '-aq', '--filter', 'label=boohtacord.qa.owner='+stack.owner)
            assert not remaining, 'Owned containers survived cleanup'
            report['owned_resources_removed'] = True
            report['source_unchanged'] = fingerprints() == report['source_files']
            if not report['source_unchanged']:
                report['status'] = 'FAIL'
            (destination/'report.json').write_text(json.dumps(report, indent=2)+'\n')
            assert report['source_unchanged'], 'Source changed during acceptance'
    print('Owned built-Web history acceptance PASS')


if __name__ == '__main__':
    main()
