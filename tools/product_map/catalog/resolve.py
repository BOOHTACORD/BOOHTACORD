"""Resolve component entrypoints from the canonical parity registry."""
from copy import deepcopy


def resolve_catalog(curated, registry):
    parity = {}
    for group in registry.values():
        for row in group['parity']:
            if row['id'] in parity:
                raise ValueError(f'duplicate parity ID: {row["id"]}')
            parity[row['id']] = row
    result = deepcopy(curated)
    for component in result['components']:
        source = component.pop('source')
        try:
            component['paths'] = [parity[source['parity_id']]['platforms']
                                  [source['platform']]['entrypoint']]
        except (KeyError, TypeError) as error:
            raise ValueError(f'invalid parity source: {component["id"]}') from error
    return result
