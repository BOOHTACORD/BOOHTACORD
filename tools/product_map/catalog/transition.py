"""Prevent removal or historical rewriting of registered identifiers."""


def validate_transition(previous, current):
    for group in ('features', 'components'):
        old = {item['id']: item for item in previous[group]}
        new = {item['id']: item for item in current[group]}
        removed = old.keys() - new.keys()
        if removed:
            raise ValueError(f'removed {group} IDs require tombstones: {sorted(removed)}')
        if group != 'features':
            continue
        for identifier, before in old.items():
            after = new[identifier]
            prior, updated = before['target_revision'], after['target_revision']
            if prior is not None and (updated is None or updated < prior):
                raise ValueError(f'revision decreased: {identifier}')
            revisions = before['behavior_revisions']
            if after['behavior_revisions'][:len(revisions)] != revisions:
                raise ValueError(f'historical revision changed: {identifier}')
