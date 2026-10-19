"""Decode exactly the three bounded, direct and unambiguous release receipts."""
import json
import re

GATES = ('backend', 'web', 'contracts')
FIELDS = {'source_revision', 'gate', 'status'}


def unique(pairs):
    value = {}
    for key, item in pairs:
        if key in value:
            raise ValueError('Duplicate gate receipt field')
        value[key] = item
    return value


def read(directory, revision):
    try:
        if (not isinstance(revision, str) or not re.fullmatch('[0-9a-f]{40}', revision)
                or directory.is_symlink() or not directory.is_dir()
                or {p.name for p in directory.iterdir()} != {gate + '.json' for gate in GATES}):
            raise ValueError('Invalid gate receipt set')
        result = {}
        for gate in GATES:
            path = directory / (gate + '.json')
            if path.is_symlink() or not path.is_file() or not 0 < path.stat().st_size <= 4096:
                raise ValueError('Invalid gate receipt file')
            receipt = json.loads(path.read_text(encoding='utf-8'), object_pairs_hook=unique)
            if (not isinstance(receipt, dict) or set(receipt) != FIELDS
                    or receipt['source_revision'] != revision or receipt['gate'] != gate
                    or receipt['status'] != 'PASS'):
                raise ValueError('Invalid gate receipt identity or result')
            result[gate] = 'PASS'
        return result
    except (OSError, ValueError, TypeError):
        raise ValueError('Release requires exactly three direct, bounded, unique PASS receipts for this source') from None
