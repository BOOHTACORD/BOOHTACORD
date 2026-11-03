"""Bounded synthetic PNG/JSON payloads; never echo untrusted report contents."""
import hashlib
import json
import re
import unicodedata
from pathlib import PurePosixPath

MAX_FILE = 16 * 1024 * 1024
MAX_TOTAL = 512 * 1024 * 1024
MAX_FILES = 2000
DEVICES = {'CON', 'PRN', 'AUX', 'NUL', 'CONIN$', 'CONOUT$'} | {
    prefix + str(number) for prefix in ('COM', 'LPT') for number in range(1, 10)}
SENSITIVE = {'password', 'session', 'session_id', 'session_token', 'access_token',
             'refresh_token', 'csrf', 'csrf_token', 'token', 'jwt', 'cookie',
             'authorization', 'set_cookie'}


def require(value):
    if not value:
        raise ValueError('Synthetic capture package identity, paths, privacy or integrity is invalid')


def unique(pairs):
    value = {}
    for key, item in pairs:
        require(key not in value)
        value[key] = item
    return value


def strict_json(raw):
    try:
        return json.loads(raw, object_pairs_hook=unique, parse_constant=lambda _: require(False))
    except (ValueError, UnicodeError):
        raise ValueError('Synthetic capture JSON is invalid') from None


def safe_json(value):
    if isinstance(value, dict):
        for key, item in value.items():
            if key.lower().replace('-', '_') in SENSITIVE:
                require(item is None or type(item) is bool
                        or (isinstance(item, str) and item.lower() in ('', '<redacted>', '[redacted]')))
            safe_json(item)
    elif isinstance(value, list):
        for item in value:
            safe_json(item)
    elif isinstance(value, str):
        require(not re.search(r'eyJ[A-Za-z0-9_-]{12,}\.[A-Za-z0-9_-]{12,}\.[A-Za-z0-9_-]{12,}', value))


def logical_path(value):
    require(isinstance(value, str) and 0 < len(value) <= 240
            and not any(ord(c) < 32 or c in '\\:<>"|?*' for c in value))
    path = PurePosixPath(value)
    require(not path.is_absolute() and '..' not in path.parts and path.as_posix() == value
            and path.suffix in ('.png', '.json'))
    require(all(part.rstrip(' .') == part and part.split('.')[0].upper() not in DEVICES for part in path.parts))
    return path


def portable_paths(names):
    spellings = {}
    files = set(names)
    for name in names:
        logical = logical_path(name)
        for index in range(1, len(logical.parts) + 1):
            original = '/'.join(logical.parts[:index])
            require(index == len(logical.parts) or original not in files)
            folded = unicodedata.normalize('NFC', original).casefold()
            require(folded not in spellings or spellings[folded] == original)
            spellings[folded] = original


def identity(value):
    fields = {'repository', 'source_revision', 'run_id', 'run_attempt', 'namespace',
              'component', 'profile', 'platform'}
    require(isinstance(value, dict) and set(value) == fields
            and all(isinstance(item, str) for item in value.values()))
    require(value['repository'] == 'BOOHTACORD/BOOHTACORD'
            and re.fullmatch('[0-9a-f]{40}', value['source_revision'])
            and re.fullmatch('[1-9][0-9]{0,19}', value['run_id'])
            and re.fullmatch('[1-9][0-9]{0,3}', value['run_attempt'])
            and re.fullmatch('[a-z][a-z0-9-]{0,' + ('47' if value['component'] == 'flutter' else '39') + '}', value['namespace'])
            and value['platform'] in ('linux', 'windows', 'macos'))
    require((value['component'] == 'flutter' and value['profile'] == 'dart')
            or (value['component'] == 'web' and value['profile'] in
                ('browser-shell', 'browser-content', 'browser-voice', 'browser-conversations')))


def payload(path, extension):
    require(not path.is_symlink() and path.resolve() == path and path.is_file()
            and 0 < path.stat().st_size <= MAX_FILE)
    raw = path.read_bytes()
    require(0 < len(raw) <= MAX_FILE)
    if extension == '.png':
        require(len(raw) >= 33 and raw[:16] == b'\x89PNG\r\n\x1a\n\0\0\0\rIHDR'
                and all(0 < int.from_bytes(raw[i:i + 4], 'big') <= 10000 for i in (16, 20)))
    else:
        require(extension == '.json' and len(raw) <= 4 * 1024 * 1024)
        safe_json(strict_json(raw))
    return raw, hashlib.sha256(raw).hexdigest()
