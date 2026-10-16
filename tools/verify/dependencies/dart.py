"""Check repository-local Dart import edges without reading generated build trees."""
import posixpath
import re
import subprocess
from pathlib import Path

LIB = 'clients/flutter/lib/'
TEST = 'clients/flutter/test/'
QA = 'tools/qa/'
INTEGRATION = 'clients/flutter/integration_test/'


def local_targets(path, source):
    for uri in re.findall(r"(?m)^\s*(?:import|export|part)\s+['\"]([^'\"]+)['\"]", source):
        if uri.startswith('package:boohtacord_desktop/'):
            yield LIB + uri.removeprefix('package:boohtacord_desktop/')
        elif ':' not in uri:
            yield posixpath.normpath(posixpath.join(posixpath.dirname(path), uri))


def violations(sources):
    errors = []
    for path, source in sources.items():
        for target in local_targets(path, source):
            if target not in sources:
                errors.append(f'{path}: local Dart dependency is absent or ignored: {target}')
            if path.startswith(LIB) and target.startswith((QA, INTEGRATION)):
                errors.append(f'{path}: production Dart imports QA: {target}')
            if '/lib/src/features/' in path and any(target.startswith(LIB + prefix) for prefix in
                    ('src/app_state.dart', 'src/app.dart', 'src/app/', 'src/screens/', 'src/widgets/')):
                errors.append(f'{path}: a feature owner depends on application UI: {target}')
    return errors


def discover_sources(root):
    names = subprocess.check_output(['git', 'ls-files', '--cached', '--others', '--exclude-standard', '-z', '--',
                                     LIB, TEST, QA, INTEGRATION], cwd=root).decode().split('\0')
    available = {name for name in names if name.endswith('.dart') and (root / name).is_file()}
    pending = sorted(name for name in available if name.startswith((LIB, TEST)))
    sources = {}
    while pending:
        name = pending.pop()
        if name in sources:
            continue
        source = (root / name).read_text(encoding='utf-8')
        sources[name] = source
        # QA entry points can intentionally target a private build context. Only
        # QA imports reachable from this Flutter project belong to its graph.
        pending.extend(target for target in local_targets(name, source)
                       if target.startswith((QA, INTEGRATION)) and target in available and target not in sources)
    return sources


def main():
    root = Path(__file__).resolve().parents[3]
    sources = discover_sources(root)
    errors = violations(sources)
    if errors:
        raise RuntimeError('\n'.join(errors))
    print(f'Dart local import edges and feature/UI boundaries: OK ({len(sources)} files)')


if __name__ == '__main__':
    main()
