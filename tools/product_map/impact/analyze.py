"""Project exact mapped paths to features; do not infer unmapped ownership."""
from pathlib import PurePosixPath
from tools.product_map.ownership.new_paths import scoped_component_ids, scoped_feature_ids

RUNTIME_ROOTS = ('backend/', 'clients/web/', 'clients/flutter/', 'contracts/',
                 'deploy/', 'docker/')


def analyze(paths, catalog):
    paths = set(paths)
    for path in paths:
        if (not isinstance(path, str) or not path or '\\' in path or ':' in path or
                PurePosixPath(path).is_absolute() or
                any(part in ('', '.', '..') for part in path.split('/')) or
                any(ord(char) < 32 for char in path)):
            raise ValueError(f'unsafe changed path: {path!r}')
    components = catalog['components']
    matched = {item['id'] for item in components if paths.intersection(item['paths'])}
    matched.update(identifier for path in paths for identifier in scoped_component_ids(path, catalog))
    while True:
        consumers = {item['id'] for item in components
                     if matched.intersection(item.get('depends_on', []))} - matched
        if not consumers:
            break
        matched.update(consumers)
    mapped_paths = {path for item in components for path in item['paths']}
    direct = {item['id'] for item in catalog['features']
              if matched.intersection(item['components'])}
    direct.update(feature_id for path in paths for feature_id in scoped_feature_ids(path, catalog))
    impacted = set(direct)
    while True:
        new = {item['id'] for item in catalog['features']
               if impacted.intersection(item.get('depends_on', []))} - impacted
        if not new:
            break
        impacted.update(new)
    unknown = {p for p in paths - mapped_paths if p.startswith(RUNTIME_ROOTS)
               and not scoped_feature_ids(p, catalog)}
    return {'coverage': 'INCOMPLETE', 'components': sorted(matched),
            'direct_features': sorted(direct), 'dependent_features': sorted(impacted - direct),
            'unclassified_runtime_paths': sorted(unknown),
            'other_paths': sorted(p for p in paths - mapped_paths - unknown
                                  if not scoped_feature_ids(p, catalog))}
