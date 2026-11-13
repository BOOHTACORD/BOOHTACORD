"""Reject dangling feature dependencies and directed cycles."""
from collections import deque


def validate_dependencies(features):
    dependencies = {f['id']: set(f.get('depends_on', [])) for f in features}
    reverse = {key: set() for key in dependencies}
    for key, refs in dependencies.items():
        if not refs <= dependencies.keys():
            raise ValueError(f'missing feature dependency: {key}')
        for ref in refs:
            reverse[ref].add(key)
    ready = deque(key for key, refs in dependencies.items() if not refs)
    visited = 0
    while ready:
        item = ready.popleft()
        visited += 1
        for dependent in reverse[item]:
            dependencies[dependent].remove(item)
            if not dependencies[dependent]:
                ready.append(dependent)
    if visited != len(features):
        raise ValueError('feature dependency cycle')
