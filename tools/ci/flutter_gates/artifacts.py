"""Measure actual public CI captures and the builder's inspected debug APK."""
import hashlib
import json
import re
from tools.build.android.signature import APPLICATION

VISUALS = (
    'R14-navigation-top.png', 'maintenance-banner-safe-area-390x800.png',
    'flutter-topology-create-desktop-1440x900@2x.png',
    'flutter-topology-destructive-desktop-1440x900@2x.png',
    'flutter-screen-share-mobile-ime-2x-393x852.png',
    'flutter-profile-logout-confirmation-mobile-393x852@3x.png',
    'flutter-settings-revoke-sessions-confirmation-mobile-393x852@3x.png',
) + tuple(f'flutter-admin-{section}-{profile}-{size}.png'
          for section in ('guild', 'members', 'roles', 'channels', 'audit', 'media', 'readiness')
          for profile, size in (('mobile', '393x852'), ('mobile-large-text', '393x852'), ('desktop', '1440x900')))


def regular(path, maximum):
    if path.is_symlink() or path.resolve() != path or not path.is_file() or not 0 < path.stat().st_size <= maximum:
        raise ValueError('Required public CI artifact is missing, indirect, empty or oversized')
    with path.open('rb') as stream:
        digest = hashlib.file_digest(stream, 'sha256').hexdigest()
    return {'bytes': path.stat().st_size, 'sha256': digest}


def visuals(directory):
    result = {}
    for name in VISUALS:
        path = directory / name
        result[name] = regular(path, 16 * 1024 * 1024)
        with path.open('rb') as stream:
            header = stream.read(33)
        if (len(header) != 33 or header[:16] != b'\x89PNG\r\n\x1a\n\0\0\0\rIHDR'
                or not all(0 < int.from_bytes(header[i:i + 4], 'big') <= 10000 for i in (16, 20))):
            raise ValueError('Required capture is not a bounded PNG image')
    return result


def android(directory, source):
    manifest = directory / 'artifact-manifest.json'
    regular(manifest, 1024 * 1024)
    value = json.loads(manifest.read_text(encoding='utf-8'))
    signing = value.get('signing', {})
    fingerprint = signing.get('certificate_sha256', '')
    if (value.get('schema_version') != 1 or value.get('source_revision') != source
            or value.get('source_dirty') is not False or value.get('platform') != 'android'
            or value.get('application_id') != APPLICATION or value.get('architectures') != ['universal']
            or signing.get('status') != 'debug' or not re.fullmatch('[0-9a-f]{64}', fingerprint)
            or signing.get('apks', {}).get('app-debug.apk', {}).get('certificate_sha256') != fingerprint):
        raise ValueError('Android debug artifact identity/source/signing evidence differs')
    files = value.get('files', {})
    if 'app-debug.apk' not in files or not 1 <= len(files) <= 10:
        raise ValueError('Inspected Android debug APK is missing')
    result = {}
    for name, measured in files.items():
        if not re.fullmatch('[A-Za-z0-9_.-]{1,100}', name) or name in ('artifact-manifest.json', 'SHA256SUMS'):
            raise ValueError('Unexpected Android public artifact name')
        result[name] = regular(directory / name, 256 * 1024 * 1024)
        if result[name] != measured:
            raise ValueError('Measured Android artifact digest/size differs')
    result[manifest.name] = regular(manifest, 1024 * 1024)
    checksums = directory / 'SHA256SUMS'
    result[checksums.name] = regular(checksums, 4096)
    expected = ''.join(item['sha256'] + '  ' + name + '\n' for name, item in result.items() if name != 'SHA256SUMS')
    # The retained manifest orders paths lexically; accept only exact, unique lines.
    if sorted(checksums.read_text().splitlines()) != sorted(expected.splitlines()):
        raise ValueError('Retained Android checksum manifest differs')
    return result
