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
            selected = set(feature['components'])
            pending = list(selected)
            while pending:
                for dependency in components[pending.pop()].get('depends_on', []):
                    if dependency not in selected:
                        selected.add(dependency)
                        pending.append(dependency)
            row['components'] = [deepcopy(components[key]) for key in sorted(selected)]
            row['component_edges'] = [
                {'from': key, 'to': dependency, 'type': 'depends_on'}
                for key in sorted(selected)
                for dependency in sorted(components[key].get('depends_on', []))
            ]
    return result
