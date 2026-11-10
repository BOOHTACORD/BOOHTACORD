"""Viewport profiles and checks for source-resolution browser captures."""
import hashlib
import struct


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
            ('M22', 'voice-prejoin.png'),
            ('M23', 'channel-log.png'),
        ]
    if width == 1440:
        return [
            ('D01', 'channel-text.png'),
            ('D02', 'channel-text-actions.png'),
            ('D03', 'dm-list.png'),
            ('D15', 'voice-prejoin.png'),
            ('D18', 'channel-log.png'),
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
