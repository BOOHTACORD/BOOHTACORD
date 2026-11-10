"""Find new unowned runtime files without treating the baseline as classified."""
import re

RUNTIME_ROOTS = ('backend/internal/', 'backend/cmd/', 'clients/web/src/', 'clients/web/public/',
                 'clients/flutter/lib/', 'clients/flutter/android/', 'clients/flutter/ios/',
                 'clients/flutter/windows/', 'clients/flutter/macos/', 'contracts/', 'deploy/', 'docker/')
TEST_SUFFIX = re.compile(r'(?:_test\.go|_test\.dart|\.(?:test|spec)\.[cm]?[jt]sx?)\Z')


def is_runtime(path):
    return path.startswith(RUNTIME_ROOTS) and not TEST_SUFFIX.search(path)


def classify_new_paths(previous, current, catalog):
    components = {item['id']: item for item in catalog['components']}
    reachable = {ref for feature in catalog['features'] for ref in feature['components']}
    pending = list(reachable)
    while pending:
        for dependency in components[pending.pop()].get('depends_on', []):
            if dependency not in reachable:
                reachable.add(dependency)
                pending.append(dependency)
    mapped = {path for identifier in reachable for path in components[identifier]['paths']}
    return sorted(path for path in set(current) - set(previous)
                  if is_runtime(path) and path not in mapped)
