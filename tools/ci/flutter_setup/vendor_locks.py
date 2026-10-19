"""Install reviewed public locks for vendor regressions and recursive analysis."""
import hashlib
import json
import re
from tools.ci.toolchains.spec import public_bytes

PROJECTS = {'livekit_client':'livekit_client', 'flutter_webrtc':'flutter_webrtc',
            'livekit_example':'livekit_client/example'}


def validate(root, name):
    if name not in PROJECTS:
        raise ValueError('Unsupported vendor regression project')
    manifest = json.loads(public_bytes(root, 'tools/ci/flutter_setup/vendor-locks.json'))
    if set(manifest) != set(PROJECTS):
        raise ValueError('Vendor and recursively analyzed example locks required')
    spec = public_bytes(root, 'clients/flutter/packages/' + PROJECTS[name] + '/pubspec.yaml').replace(b'\r\n', b'\n')
    lock = public_bytes(root, 'tools/ci/flutter_setup/locks/' + name + '.lock').replace(b'\r\n', b'\n')
    if (hashlib.sha256(spec).hexdigest() != manifest[name]['pubspec_sha256']
            or hashlib.sha256(lock).hexdigest() != manifest[name]['lock_sha256']):
        raise ValueError('Vendor pubspec/lock requires an explicit dependency review')
    return lock


def prepare(root, name):
    names = (name, 'livekit_example') if name == 'livekit_client' else (name,)
    outputs = []
    for project in names:
        lock = validate(root, project)
        directory = root / 'clients/flutter/packages' / PROJECTS[project]
        target = directory / 'pubspec.lock'
        if directory.resolve() != directory or target.is_symlink():
            raise ValueError('Indirect vendor lock output rejected')
        outputs.append((target, lock))
    for target, lock in outputs:
        target.write_bytes(lock)


def audit_public(root):
    import yaml
    paths = {('livekit_client','flutter_webrtc'):'../flutter_webrtc',
             ('livekit_example','livekit_client'):'..'}
    for name in PROJECTS:
        value = yaml.safe_load(validate(root, name))
        for package, dependency in value['packages'].items():
            source, detail = dependency['source'], dependency['description']
            if source == 'hosted':
                if (detail.get('url') != 'https://pub.dev'
                        or not re.fullmatch('[0-9a-f]{64}', detail.get('sha256', ''))):
                    raise ValueError('Vendor lock must use public content-verified hosted packages')
            elif source == 'path':
                expected = paths.get((name, package))
                if expected is None or detail != {'path':expected,'relative':True}:
                    raise ValueError('Only the existing local SDK/example dependency edges are permitted')
            elif source != 'sdk' or detail != 'flutter':
                raise ValueError('Unsupported vendor lock source')
