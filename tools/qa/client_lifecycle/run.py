"""Run actual production browser components against an owned disposable stack."""
import argparse
import hashlib
import json
import os
import struct
import subprocess
import tempfile
import time
from pathlib import Path
from .services import local_origin, output, run
from .stack import Stack
from .telemetry import verify


VIEWPORT_PROFILES = {
    390: {
        'name': 'mobile-390x844', 'width': 390, 'height': 844,
        'is_mobile': True, 'device_scale_factor': 3, 'has_touch': True,
    },
    393: {
        'name': 'mobile-393x852', 'width': 393, 'height': 852,
        'is_mobile': True, 'device_scale_factor': 3, 'has_touch': True,
    },
    1024: {
        'name': 'tablet-1024x768', 'width': 1024, 'height': 768,
        'is_mobile': False, 'device_scale_factor': 1, 'has_touch': False,
    },
    1440: {
        'name': 'desktop-1440x900', 'width': 1440, 'height': 900,
        'is_mobile': False, 'device_scale_factor': 2, 'has_touch': False,
    },
}


def viewport_profile(width):
    try:
        return dict(VIEWPORT_PROFILES[width])
    except KeyError as error:
        raise ValueError(f'unsupported client lifecycle viewport width: {width}') from error


def catalog_capture_plan(width):
    if width == 393:
        return [
            ('M01', 'navigation-overlay.png'),
            ('M02', 'channel-text.png'),
            ('M03', 'channel-text-actions.png'),
        ]
    if width == 1440:
        return [
            ('D01', 'channel-text.png'),
            ('D02', 'channel-text-actions.png'),
            ('D03', 'dm-list.png'),
        ]
    return []


def verify_catalog_captures(width, destination, root):
    viewport = viewport_profile(width)
    expected_raster = (viewport['width'] * viewport['device_scale_factor'],
                       viewport['height'] * viewport['device_scale_factor'])
    captures = []
    for screen_id, filename in catalog_capture_plan(width):
        path = destination/filename
        if not path.is_file():
            raise AssertionError(f'{screen_id} source-sized capture missing: {path}')
        data = path.read_bytes()
        if data[:8] != b'\x89PNG\r\n\x1a\n' or len(data) < 24:
            raise AssertionError(f'{screen_id} capture is not a valid PNG: {path}')
        raster = struct.unpack('>II', data[16:24])
        if raster != expected_raster:
            raise AssertionError(f'{screen_id} raster {raster} does not match {expected_raster}')
        captures.append({
            'catalog_slot': screen_id,
            'after': {
                'path': str(path.relative_to(root)),
                'sha256': hashlib.sha256(data).hexdigest(),
                'raster': f'{raster[0]}x{raster[1]}',
            },
        })
    return captures


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--width', type=int, choices=tuple(VIEWPORT_PROFILES), default=1440)
    parser.add_argument('--critical', action='store_true')
    args = parser.parse_args()
    viewport = viewport_profile(args.width)
    started = time.monotonic()
    root = Path(__file__).resolve().parents[3]
    origin = local_origin('https://localhost:4810')
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
            script = root/'tools/qa/client_lifecycle/scenario.mjs'
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
