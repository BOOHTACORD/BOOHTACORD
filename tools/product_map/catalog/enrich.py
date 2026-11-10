"""Attach curated relationships without duplicating parity-owned properties."""
from copy import deepcopy


def enrich_projection(projection, catalog):
    features = {f['id']: f for f in catalog['features']}
    components = {c['id']: c for c in catalog['components']}
    result = deepcopy(projection)
    for row in result:
        feature = features.get(row['id'])
        if feature is not None:
            row['title'] = feature['title']
            row['components'] = [deepcopy(components[key])
                                 for key in feature['components']]
    return result
