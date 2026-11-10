"""Load and validate the currently registered, possibly incomplete slices."""
import json

from .resolve import resolve_catalog
from .validation import validate_catalog


def load_curated_catalog(root, registry):
    directory = root / 'product-map/features'
    if not directory.resolve().is_relative_to(root.resolve()):
        raise ValueError('catalog directory leaves repository')
    files = sorted(directory.glob('*/*.yaml'))
    if not files:
        raise ValueError('product catalog has no registered slices')
    curated = {'features': [], 'components': []}
    for path in files:
        if not path.resolve().is_relative_to(directory.resolve()):
            raise ValueError('catalog path leaves catalog directory')
        document = json.loads(path.read_text(encoding='utf-8'))
        for key in curated:
            curated[key].extend(document[key])
    resolved = resolve_catalog(curated, registry)
    all_ids = {row['id'] for group in registry.values() for row in group['parity']}
    covered = {ref for feature in resolved['features'] for ref in feature['parity_ids']}
    if not covered <= all_ids:
        raise ValueError('unknown parity ID in curated catalog')
    validate_catalog(resolved, root, all_ids)
    parity = {row['id']: row for group in registry.values() for row in group['parity']}
    components = {item['id']: item for item in resolved['components']}
    for feature in resolved['features']:
        paths = {path for key in feature['components'] for path in components[key]['paths']}
        for ref in feature['parity_ids']:
            required = {row['entrypoint'] for row in parity[ref]['platforms'].values()}
            if not required <= paths:
                raise ValueError(f'component entrypoint mapping is stale: {ref}')
    return resolved
