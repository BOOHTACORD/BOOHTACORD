"""Read the existing parity registry without manufacturing platform claims."""

from .status import source_status

PLATFORMS = ('web', 'windows', 'macos', 'android', 'ios')
EXISTING = {'web', 'android', 'ios'}


def import_parity(catalog):
    result, seen = [], set()
    for group, value in sorted(catalog.items()):
        for row in value['parity']:
            identifier = row['id']
            if identifier in seen:
                raise ValueError(f'duplicate parity ID: {identifier}')
            if set(row['platforms']) != EXISTING:
                raise ValueError(f'platform coverage differs: {identifier}')
            seen.add(identifier)
            platforms = {}
            for name in PLATFORMS:
                original = row['platforms'].get(name, {})
                declared = original.get('runtime', 'NOT_VERIFIED')
                platforms[name] = {
                    'applicability': 'UNKNOWN',
                    'implementation': 'UNKNOWN',
                    'target_revision': None,
                    'implemented_revision': None,
                    'source_status': source_status('UNKNOWN', 'UNKNOWN', None, None),
                    'released': 'UNKNOWN',
                    'runtime': 'NOT_VERIFIED' if declared == 'PASS' else declared,
                    'declared_runtime': declared,
                    'entrypoint': original.get('entrypoint'),
                    'tests': original.get('tests', []),
                }
            result.append({'id': identifier, 'group': group,
                           'description': row['expected'], 'issue': row['issue'],
                           'platforms': platforms})
    return sorted(result, key=lambda item: item['id'])
