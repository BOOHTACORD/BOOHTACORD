"""Measure the previous native Web store against the same actual API fixture."""
import argparse
import hashlib
import io
import json
import os
import re
import subprocess
import tarfile
import tempfile
from pathlib import Path
from tools.qa.client_lifecycle.services import LABEL, output, run
from tools.qa.client_lifecycle.stack import Stack


def extract(data, destination):
    with tarfile.open(fileobj=io.BytesIO(data)) as archive:
        for member in archive.getmembers():
            path = (destination/member.name).resolve()
            if not path.is_relative_to(destination.resolve()) or member.issym() or member.islnk():
                raise ValueError('Unsafe baseline source archive')
        archive.extractall(destination, filter='data')


def archive_source(root, revision):
    paths = ['clients/web', 'contracts']
    optional = 'tools/audio/research_dfn_web/stage.mjs'
    found = subprocess.check_output(['git', 'ls-tree', '-r', '--name-only', revision, '--', optional], cwd=root)
    if found.decode('utf-8').strip() == optional:
        paths.append(optional)
    return subprocess.check_output(['git', 'archive', revision, *paths], cwd=root)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--revision', required=True)
    args = parser.parse_args()
    if not re.fullmatch('[a-f0-9]{40}', args.revision):
        raise ValueError('Use an exact source commit')
    root = Path(__file__).resolve().parents[3]
    destination = root/'.out/refresh-baseline'
    destination.mkdir(parents=True, exist_ok=True)
    source = archive_source(root, args.revision)
    with tempfile.TemporaryDirectory(prefix='qa-baseline-', dir=root/'.out') as directory:
        work = Path(directory)
        stack = Stack(root, work)
        try:
            extract(source, work/'source')
            web = work/'source/clients/web'
            run('npm', 'ci', '--no-audit', '--no-fund', cwd=web, stdout=subprocess.DEVNULL)
            run('npm', 'run', 'build', '--', '--outDir', str(root/'clients/web/dist'), '--emptyOutDir', cwd=web, stdout=subprocess.DEVNULL)
            stack.start()
            inputs = work/'input.json'
            inputs.write_text(json.dumps(dict(password=stack.password, directory=str(destination))))
            inputs.chmod(0o600)
            script = root/'tools/qa/refresh_baseline/scenario.mjs'
            environment = dict(os.environ, QA_ORIGIN='https://localhost:4810', QA_INPUT=str(inputs))
            container = os.environ.get('QA_BROWSER_CONTAINER')
            if container:
                assert output('docker', 'inspect', container, '--format', '{{index .Config.Labels "'+LABEL+'"}}') == os.environ['QA_BROWSER_OWNER']
                run('docker', 'exec', '-e', 'QA_ORIGIN='+environment['QA_ORIGIN'], '-e', 'QA_INPUT='+str(inputs), container, 'node', str(script))
            else:
                run('node', str(script), env=environment)
            report = json.loads((destination/'report.json').read_text())
            report.update(client_source_revision=args.revision, baseline_archive_sha256=hashlib.sha256(source).hexdigest(),
                          harness_revision=output('git', '-C', str(root), 'rev-parse', 'HEAD'))
        finally:
            stack.close()
            run('npm', 'run', 'build', cwd=root/'clients/web', stdout=subprocess.DEVNULL)
    report['owned_resources_removed'] = True
    (destination/'report.json').write_text(json.dumps(report, indent=2)+'\n')
    print('Actual previous-client REST measurement PASS')


if __name__ == '__main__':
    main()
