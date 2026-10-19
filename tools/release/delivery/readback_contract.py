"""Accept only a bounded fresh acknowledgement for this exact install attempt."""
from datetime import datetime, timezone
import json
import re

VOLUMES = ('postgres-data', 'attachments-data', 'caddy-data', 'caddy-config')
KEYS = {'schema_version', 'kind', 'status', 'source_revision', 'controller_revision', 'nonce',
        'previous_source_revision', 'persistent_volumes', 'schema_relation', 'migration_inventory_sha256',
        'running_images', 'checked_at', 'volumes', 'schema_sha256', 'health', 'sources'}


def unique(rows):
    result = {}
    for key, value in rows:
        if key in result: raise ValueError
        result[key] = value
    return result


def validate(raw, source, controller, prior, nonce):
    try:
        if not isinstance(raw, bytes) or not 0 < len(raw) <= 16384: raise ValueError
        for value in (source, controller, prior):
            if not isinstance(value, str) or not re.fullmatch('[a-f0-9]{40}', value): raise ValueError
        if not isinstance(nonce, str) or not re.fullmatch('[a-f0-9]{32}', nonce): raise ValueError
        result = json.loads(raw, object_pairs_hook=unique)
        if not isinstance(result, dict) or set(result) != KEYS: raise ValueError
        expected = {'kind': 'installed-source-readback', 'status': 'PASS', 'source_revision': source,
                    'controller_revision': controller, 'nonce': nonce, 'previous_source_revision': prior,
                    'persistent_volumes': 'PASS', 'health': 'PASS', 'sources': {'api': source, 'web': source}}
        if type(result['schema_version']) is not int or result['schema_version'] != 1: raise ValueError
        if any(result[key] != value for key, value in expected.items()): raise ValueError
        if result['schema_relation'] not in ('unchanged', 'changed-with-migration-inventory'): raise ValueError
        for key in ('schema_sha256', 'migration_inventory_sha256'):
            if not isinstance(result[key], str) or not re.fullmatch('[a-f0-9]{64}', result[key]): raise ValueError
        for key, names, pattern in (('volumes', set(VOLUMES), '[a-f0-9]{64}'),
                                    ('running_images', {'api', 'web'}, 'sha256:[a-f0-9]{64}')):
            values = result[key]
            if (not isinstance(values, dict) or set(values) != names
                    or any(not isinstance(v, str) or not re.fullmatch(pattern, v) for v in values.values())): raise ValueError
        stamp = datetime.fromisoformat(result['checked_at'])
        if stamp.tzinfo is None or not -30 <= (datetime.now(timezone.utc) - stamp).total_seconds() <= 300:
            raise ValueError
        return result
    except Exception:
        raise ValueError('Fresh installed-source acknowledgement differs') from None
