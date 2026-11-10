"""Run actual production browser components against an owned disposable stack."""
import argparse
import hashlib
import json
import os
import subprocess
import tempfile
import time
from pathlib import Path
from .services import local_origin, output, run
from .stack import Stack
from .telemetry import verify
from .destination import fresh_capture_destination
from .journey.captures import (VIEWPORT_PROFILES, catalog_capture_plan,
                               verify_catalog_captures, viewport_profile)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--width', type=int, choices=tuple(VIEWPORT_PROFILES), default=1440)
    parser.add_argument('--critical', action='store_true')
    parser.add_argument('--portable-proxy', action='store_true', help='bridge proxy for macOS Colima')
    parser.add_argument('--output-root', help='fresh per-width capture directory inside checkout .out; existing runs are rejected')
    args = parser.parse_args()
    viewport = viewport_profile(args.width)
    started = time.monotonic()
    root = Path(__file__).resolve().parents[3]
    origin = local_origin('https://localhost:4810')
    if args.output_root:
        destination = fresh_capture_destination(root, args.output_root, args.width)
    else:
        destination = root/'.out/client-lifecycle'/str(args.width)
        destination.mkdir(parents=True, exist_ok=True)
    build_environment = dict(os.environ, VITE_PUBLIC_ORIGIN=origin)
    run('npm', 'run', 'build', cwd=root/'clients/web', env=build_environment,
        stdout=subprocess.DEVNULL)
    print('stage=production-client-built', flush=True)
    with tempfile.TemporaryDirectory(prefix='boohtacord-client-qa-', dir=root/'.out') as temporary:
        work = Path(temporary)
        if args.critical:
            from tools.qa.critical_client_acceptance.stack import Stack as ActualStack
        else:
            ActualStack = Stack
        if args.portable_proxy:
            from tools.qa.local_features.stack import Stack as ActualStack
        stack = ActualStack(root, work)
        try:
            stack.start()
            print('stage=isolated-tls-api-ready', flush=True)
            private = work/'private.json'
            inputs = work/'input.json'
            inputs.write_text(json.dumps({'password': stack.password, 'width': args.width,
                                         'viewport': viewport, 'directory': str(destination),
                                         'critical': args.critical}))
            inputs.chmod(0o600)
            environment = dict(os.environ, QA_ORIGIN=origin, QA_INPUT=str(inputs), QA_PRIVATE=str(private), QA_DB_OWNER=stack.owner)
            script = root/'tools/qa/client_lifecycle/journey/scenario.mjs'
            container = os.environ.get('QA_BROWSER_CONTAINER')
            if container:
                from .services import LABEL
                owner = output('docker', 'inspect', container, '--format', '{{index .Config.Labels "'+LABEL+'"}}')
                assert owner and owner == os.environ.get('QA_BROWSER_OWNER'), 'Foreign browser container'
                run('docker', 'exec', '-e', 'QA_ORIGIN='+origin, '-e', 'QA_INPUT='+str(inputs),
                    '-e', 'QA_PRIVATE='+str(private), '-e', 'QA_DB_OWNER='+stack.owner, container, 'node', str(script))
            else:
                run('node', str(script), env=environment)
            state = json.loads(private.read_text())
            metrics = verify(state)
            print('stage=actual-tempo-verified', flush=True)
            stack.restart()
            with __import__('urllib.request', fromlist=['urlopen']).urlopen(
                    'http://127.0.0.1:4820/api/v1/guild-profile') as response:
                profile = json.load(response)
            assert profile['name'] == 'Автономная гильдия' and profile['revision'] == state['revision']
            count = output('docker', 'exec', stack.owner+'-db', 'psql', '-U', 'qa', '-d', 'qa', '-Atc',
                           "select count(*) from messages where kind='SYSTEM_WELCOME'")
            assert count == '1', 'Welcome persistence changed after API restart'
            report = json.loads((destination/'browser.json').read_text())
            report.update(telemetry=metrics, persisted_after_restart=True,
                          source_revision=output('git', '-C', str(root), 'rev-parse', 'HEAD'))
            report['source_sized_catalog_captures'] = verify_catalog_captures(
                args.width, destination, root)
            sources = list((root/'tools/qa/client_lifecycle').glob('*.py'))
            sources += list((root/'tools/qa/client_lifecycle').glob('*.mjs'))
            sources += list((root/'tools/qa/client_lifecycle/journey').glob('*.*'))
            sources += list((root/'tools/qa/critical_client_acceptance').glob('*.*'))
            sources += list((root/'clients/web/src').rglob('*.css'))
            sources += list((root/'clients/web/src').rglob('*.vue'))
            sources += [root/'clients/web/src/identity/AuthenticationLanding.vue', root/'clients/web/package-lock.json']
            report['source_files'] = {str(path.relative_to(root)): hashlib.sha256(path.read_bytes()).hexdigest()
                                      for path in sorted(set(sources))}
            report['api_image_id'] = output('docker', 'image', 'inspect', stack.image,
                                            '--format', '{{.Id}}')
            report['screenshots'] = {path.name: hashlib.sha256(path.read_bytes()).hexdigest()
                                     for path in destination.glob('*.png')}
            (destination/'report.json').write_text(json.dumps(report, indent=2)+'\n')
        finally:
            stack.close()
    report['owned_resources_removed'] = True
    report['elapsed_seconds'] = round(time.monotonic()-started, 2)
    (destination/'report.json').write_text(json.dumps(report, indent=2)+'\n')
    print('Autonomous real-stack acceptance PASS; owned resources removed')


if __name__ == '__main__':
    main()
