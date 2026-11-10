"""Count scoped Git paths with explicit feature-linked component ownership."""
from .new_paths import RUNTIME_ROOTS, is_runtime, mapped_feature_paths


def coverage_report(paths, catalog):
    tracked = {path for path in paths if is_runtime(path)}
    mapped = tracked.intersection(mapped_feature_paths(catalog))
    groups = {}
    for root in RUNTIME_ROOTS:
        members = {path for path in tracked if path.startswith(root)}
        owned = members.intersection(mapped)
        missing = sorted(members - owned)
        groups[root] = {'total': len(members), 'mapped': len(owned),
                        'unmapped': len(missing), 'unmapped_sample': missing[:10]}
    return {'status': 'INCOMPLETE' if tracked - mapped else 'SCOPED_PATHS_COVERED',
            'total': len(tracked), 'mapped': len(mapped), 'unmapped': len(tracked - mapped),
            'groups': groups}
