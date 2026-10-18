"""One versioned ownership map for PR gates and server/native release impact."""
from fnmatch import fnmatchcase
import hashlib
import json
from pathlib import Path

ALL = frozenset({'contracts', 'backend', 'web', 'flutter', 'windows', 'server'})
SERVER = frozenset({'contracts', 'backend', 'web', 'server'})
MAP_PATH = Path(__file__).with_name('dependencies.json')


def dependency_map():
    raw = MAP_PATH.read_bytes()
    document = json.loads(raw)
    if document.get('version') != 1 or not document.get('rules'):
        raise ValueError('Unsupported or empty dependency map')
    for rule in document['rules']:
        if (not rule.get('paths') or not all(isinstance(p, str) and p for p in rule['paths'])
                or not set(rule.get('gates', [])).issubset(ALL - {'server'})
                or 'contracts' not in rule.get('gates', [])
                or type(rule.get('server')) is not bool or type(rule.get('native')) is not bool):
            raise ValueError('Invalid dependency rule')
    return document, hashlib.sha256(raw).hexdigest()


def valid_path(path):
    return (isinstance(path, str) and bool(path) and not path.startswith('/') and '\\' not in path
            and all(part not in ('', '.', '..') for part in path.split('/')))


def classify(paths):
    document, digest = dependency_map()
    chosen, server, native, uncertain = {'contracts'}, False, False, paths is None
    for path in paths or []:
        rule = next((r for r in document['rules'] if valid_path(path)
                     and any(fnmatchcase(path, pattern) for pattern in r['paths'])), None)
        if rule is None:
            uncertain = True
            break
        chosen.update(rule['gates'])
        server, native = server or rule['server'], native or rule['native']
    if uncertain:
        chosen, server, native = set(ALL), True, True
    elif server:
        chosen.add('server')
    return {'gates': sorted(chosen), 'server_release_impact': server, 'native_release_impact': native,
            'map_version': document['version'], 'map_sha256': digest, 'uncertain': uncertain}


def select(paths):
    return set(classify(paths)['gates'])
