"""Immutable SDK/source metadata and public-only cache namespace; no YAML dependency."""
import json
from pathlib import Path
import re
import tempfile
from tools.ci.toolchains.spec import approved_versions, public_bytes


def describe(root, toolcache, system, architecture, requested, channel):
    if system not in ('Linux', 'Windows', 'macOS') or architecture not in ('X64', 'ARM64'):
        raise ValueError('Unsupported Flutter SDK platform or architecture')
    versions = approved_versions(root)
    source = json.loads(public_bytes(root, 'tools/ci/flutter_setup/source.json'))
    pins = json.loads(public_bytes(root, 'tools/verify/action_pins/pins.json'))
    installer = [p for p in pins['actions'] if p['action'] == 'subosito/flutter-action']
    if (source.get('schema_version') != 1 or pins.get('schema_version') != 1
            or source.get('installer_repository') != 'subosito/flutter-action'
            or len(installer) != 1 or source.get('installer_revision') != installer[0]['commit']
            or not re.fullmatch('[0-9a-f]{40}', source.get('installer_revision', ''))
            or not re.fullmatch('[0-9a-f]{40}', source.get('framework_revision', ''))
            or source.get('flutter') != versions['flutter'] or requested != versions['flutter']
            or channel != 'stable'):
        raise ValueError('Reviewed immutable Flutter SDK and installer inputs are required')
    normalized = architecture.lower()
    namespace = '-'.join(('v1', system, normalized, requested, source['framework_revision']))
    folder = '-'.join(({'Windows': 'win', 'Linux': 'linux', 'macOS': 'mac'}[system],
                       requested, normalized, source['framework_revision'][:12]))
    cache = toolcache.resolve() / 'boohtacord-sdk' / folder
    if cache.resolve() != cache:
        raise ValueError('Refusing an indirect Flutter SDK cache directory')
    return {'cache_key': 'boohtacord-flutter-sdk-' + namespace,
            'cache_path': cache.as_posix(), 'flutter_root': (cache / 'flutter').as_posix(),
            'architecture': normalized,
            'version': requested, 'framework_revision': source['framework_revision'],
            'dart_version': versions['dart'], 'installer_revision': source['installer_revision']}


def prepare(root, toolcache, temporary, system, architecture, requested, channel):
    value = describe(root, toolcache, system, architecture, requested, channel)
    value['pub_cache'] = Path(tempfile.mkdtemp(prefix='boohtacord-pub-',
                                            dir=temporary.resolve())).as_posix()
    return value


def check_machine(machine, expected):
    dart = machine.get('dartSdkVersion', '') if isinstance(machine, dict) else ''
    if (not isinstance(machine, dict) or machine.get('frameworkVersion') != expected['version']
            or machine.get('frameworkRevision') != expected['framework_revision']
            or not isinstance(dart, str) or dart.split(' ')[0] != expected['dart_version']):
        raise ValueError('Installed Flutter/Dart/framework revision differs from the reviewed SDK')
