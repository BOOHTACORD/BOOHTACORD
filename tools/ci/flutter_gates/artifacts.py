"""Measure actual public CI captures and the builder's inspected debug APK."""
import hashlib
import json
import re
from tools.build.android.signature import APPLICATION
from .recent_bug_visuals import VISUALS as RECENT_BUG_VISUALS
VISUALS = (
    'R14-navigation-top.png', 'maintenance-banner-safe-area-390x800.png',
    'flutter-screen-audience-viewer-strip-1024x92@2x.png',
    'flutter-screen-viewer-transient-controls-1440x900.png',
    # Flutter participant-card inline stream and voice-only previews.
    'flutter-participant-cards-stream-and-voice.png',
    'flutter-participant-card-preview-pending.png',
    'flutter-participant-cards-mobile-large-text.png',
    # #544: compact room and fullscreen viewer participant overlays.
    'voice-viewer-participants-room.png',
    'voice-viewer-participants-room-open.png',
    'voice-viewer-participants-fullscreen-open.png',
    'flutter-screen-viewer-mini-player-mobile-393x852.png',
    # #518 Flutter channel favorites navigation capture.
    'flutter-channel-favorites-1440x900.png',
    'flutter-channel-favorites-mobile-393x852.png',
    # #518 Flutter connection recovery panel parity.
    'flutter-connection-status-desktop-320x380.png',
    'flutter-connection-status-mobile-320x380.png',
    # #553 Flutter guild member voice and screen-sharing presence states.
    'guild-member-voice-channel.png',
    'guild-member-screen-sharing.png',
    'flutter-topology-create-desktop-1440x900@2x.png',
    'flutter-topology-destructive-desktop-1440x900@2x.png',
    'flutter-screen-share-mobile-ime-2x-393x852.png',
    'flutter-profile-logout-confirmation-mobile-393x852@3x.png',
    'flutter-settings-revoke-sessions-confirmation-mobile-393x852@3x.png',
    'password-reset-visibility-mobile.png',
    # #532: synthetic AUTH_BUSY response, masked password and manual retry.
    'auth-capacity-mobile.png',
    'auth-rate-limit-mobile.png',
) + tuple(f'flutter-admin-{section}-{profile}-{size}.png'
          for section in ('guild', 'members', 'roles', 'channels', 'audit', 'media', 'readiness')
          for profile, size in (('mobile', '393x852'), ('mobile-large-text', '393x852'), ('desktop', '1440x900'))) + tuple(
    f'flutter-{channel}-{profile}-{size}.png'
    for channel in ('text-channel', 'dm-conversation')
    for profile, size in (('mobile', '393x852'), ('mobile-large-text', '393x852'), ('desktop', '1440x900')))


# Finite synthetic scenarios introduced by #499–502; keep publication fail-closed.
VISUALS += tuple(
    f'parity-{surface}-{width}x480-scale{scale}.png'
    for surface in ('text', 'search', 'dm', 'audio', 'voice', 'text-ime')
    for width in (320, 390, 768, 1024, 1440) for scale in (1, 2)
) + tuple(
    f'parity-voice-{count}-{width}x480-scale2.png'
    for count in (1, 5, 10) for width in (320, 768, 1440)
) + tuple(
    f'parity-profile-{width}x480-ime-scale2.png'
    for width in (320, 390, 768, 1024, 1440)
) + tuple(
    f'parity-mini-{width}x{height}-scale2.png'
    for width in (320, 390, 768, 1024, 1440) for height in (480, 240)
) + tuple(
    f'parity-pinned-workspace-{width}x{height}-ime{ime}-scale2.png'
    for width, height in ((1440, 900), (390, 480), (320, 480)) for ime in (0, 180)
)


# #516: reviewed synthetic support widgets only; retain the exact inventory.
VISUALS += tuple(
    f'support-{width}-text{scale}.png'
    for width in (320, 393, 1440) for scale in (1.0, 2.0)
) + ('support-320-text2-ime.png',) + tuple(f'notification-settings-{width}-{scale}-{position}.png'
    for width, scale in ((393, 1), (393, 2), (1440, 1)) for position in ('top', 'bottom')) + RECENT_BUG_VISUALS


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
