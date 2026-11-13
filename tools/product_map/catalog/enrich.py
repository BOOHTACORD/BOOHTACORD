"""Attach curated relationships without duplicating parity-owned properties."""
from copy import deepcopy
from .feature_projection import project_feature


def enrich_projection(projection, catalog):
    components = {c['id']: c for c in catalog['components']}
    rows = {row['id']: deepcopy(row) for row in projection}
    for feature in sorted(catalog['features'], key=lambda item: item['id']):
        if feature['id'] in rows and feature['id'] not in feature['parity_ids']:
            raise ValueError(f'feature ID collides with unrelated parity ID: {feature["id"]}')
        for identifier in feature['parity_ids']:
            if identifier in rows:
                rows[identifier].setdefault('catalog_feature_ids', []).append(feature['id'])
        row = project_feature(feature, rows.get(feature['id']))
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
        rows[feature['id']] = row
    return list(rows.values())
