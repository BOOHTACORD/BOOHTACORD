"""Validate the explicitly incomplete curated voice catalog slice."""
import json

from .resolve import resolve_catalog
from .validation import validate_catalog


def load_voice_slice(root, registry):
    path = root / 'product-map/features/voice/core.yaml'
    curated = json.loads(path.read_text(encoding='utf-8'))
    actual = resolve_catalog(curated, registry)
    all_ids = {row['id'] for group in registry.values() for row in group['parity']}
    covered = {ref for feature in actual['features'] for ref in feature['parity_ids']}
    if not covered <= all_ids:
        raise ValueError('unknown parity ID in voice slice')
    validate_catalog(actual, root, covered)
    return actual
