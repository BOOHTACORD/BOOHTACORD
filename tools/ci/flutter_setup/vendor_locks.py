"""Install reviewed public dependency locks for standalone vendor regression tests."""
import hashlib
import json
import re
from tools.ci.toolchains.spec import public_bytes

NAMES = ('livekit_client', 'flutter_webrtc')


def validate(root, name):
    if name not in NAMES:
        raise ValueError('Unsupported vendor regression package')
    manifest = json.loads(public_bytes(root, 'tools/ci/flutter_setup/vendor-locks.json'))
    if set(manifest) != set(NAMES):
        raise ValueError('Both vendor regression locks required')
    spec = public_bytes(root, 'clients/flutter/packages/' + name + '/pubspec.yaml').replace(b'\r\n', b'\n')
    lock = public_bytes(root, 'tools/ci/flutter_setup/locks/' + name + '.lock').replace(b'\r\n', b'\n')
    if (hashlib.sha256(spec).hexdigest() != manifest[name]['pubspec_sha256']
            or hashlib.sha256(lock).hexdigest() != manifest[name]['lock_sha256']):
        raise ValueError('Vendor pubspec/lock requires an explicit dependency review')
    return lock


def prepare(root, name):
    lock = validate(root, name)
    directory = root / 'clients/flutter/packages' / name
    target = directory / 'pubspec.lock'
    if directory.resolve() != directory or target.is_symlink():
        raise ValueError('Indirect vendor lock output rejected')
    target.write_bytes(lock)


def audit_public(root):
    import yaml
    for name in NAMES:
        value = yaml.safe_load(validate(root, name))
        for package, dependency in value['packages'].items():
            source, detail = dependency['source'], dependency['description']
            if source == 'hosted':
                if (detail.get('url') != 'https://pub.dev'
                        or not re.fullmatch('[0-9a-f]{64}', detail.get('sha256', ''))):
                    raise ValueError('Vendor lock must use public content-verified hosted packages')
            elif source == 'path':
                if (name != 'livekit_client' or package != 'flutter_webrtc'
                        or detail != {'path': '../flutter_webrtc', 'relative': True}):
                    raise ValueError('Only the existing local WebRTC fork is permitted')
            elif source != 'sdk' or detail != 'flutter':
                raise ValueError('Unsupported vendor lock source')
