"""Parse bounded JSON inputs without duplicate keys or non-finite numbers."""
import json


def parse_record(raw):
    if len(raw) > 4_000_000:
        raise ValueError('JSON record is too large')

    def pairs(items):
        result = {}
        for key, value in items:
            if key in result:
                raise ValueError(f'duplicate record field: {key}')
            result[key] = value
        return result

    def reject_constant(value):
        raise ValueError(f'invalid JSON constant: {value}')

    return json.loads(raw.decode('utf-8'), object_pairs_hook=pairs,
                      parse_constant=reject_constant)
