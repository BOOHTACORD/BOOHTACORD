"""Project curated source decisions without inventing release or runtime proof."""
from copy import deepcopy

from tools.product_map.projection.importer import PLATFORMS
from tools.product_map.projection.status import source_status


def project_feature(feature, original=None):
    row = deepcopy(original) if original is not None else {
        'id': feature['id'], 'group': feature['domain'],
        'description': feature.get('description', feature['title']),
        'issue': None, 'platforms': {}}
    row['title'] = feature['title']
    row['parity_ids'] = list(feature['parity_ids'])
    for name in PLATFORMS:
        decision = feature['platforms'][name]
        platform = row['platforms'].setdefault(name, {})
        applicability, state = decision['applicability'], decision['state']
        actual, target = decision['revision'], feature['target_revision']
        platform.update(applicability=applicability, implementation=state,
                        target_revision=target, implemented_revision=actual,
                        source_status=source_status(applicability, state, target, actual))
        platform.setdefault('released', 'UNKNOWN')
        platform.setdefault('runtime', 'NOT_VERIFIED')
        platform.setdefault('declared_runtime', 'NOT_VERIFIED')
        platform.setdefault('entrypoint', None)
        platform.setdefault('tests', [])
    return row
