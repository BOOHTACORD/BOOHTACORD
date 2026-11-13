"""Validate explicit, non-overlapping capability-level ownership roots."""
import re
from pathlib import PurePosixPath

BOUNDARIES = (('backend/internal/', 4), ('clients/web/src/', 5),
              ('clients/flutter/lib/src/features/', 7))


def validate_feature_scopes(features, root):
    scopes = []
    for feature in features:
        values = feature.get('owned_roots', [])
        if not isinstance(values, list):
            raise ValueError('feature ownership roots must be a list')
        for entry in values:
            if not isinstance(entry, dict) or set(entry) != {'path', 'component'}:
                raise ValueError('ownership root requires path and component')
            if entry['component'] not in feature['components']:
                raise ValueError('ownership root component is not linked to feature')
            value = entry['path']
            if (not isinstance(value, str) or not re.fullmatch(r'(?:[A-Za-z0-9_.-]+/)+', value) or
                    any(part in ('.', '..') for part in value.split('/'))):
                raise ValueError('unsafe ownership root')
            parts = PurePosixPath(value).parts
            if not any(value.startswith(prefix) and len(parts) >= minimum
                       for prefix, minimum in BOUNDARIES):
                raise ValueError(f'ownership root is not a capability leaf: {value}')
            path = root.joinpath(*parts).resolve()
            if not path.is_relative_to(root.resolve()) or not path.is_dir():
                raise ValueError(f'missing or external ownership root: {value}')
            for old in scopes:
                if value.startswith(old) or old.startswith(value):
                    raise ValueError(f'overlapping ownership roots: {old}, {value}')
            scopes.append(value)
