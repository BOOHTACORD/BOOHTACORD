"""Finite synthetic output roots and fresh producer markers; no arbitrary inputs."""
import json
from pathlib import Path
from tools.ci.flutter_gates.artifacts import VISUALS
from . import capture_data as data

MAX_ENTRIES = 8000
WEB_ROOTS = (
    'responsive-shell-browser-results', 'issue342/browser', 'issue343/browser',
    'issue344/browser', 'qa294-search-session-browser', 'dw02-dm-starter',
    'issue346/browser', 'issue348/browser', 'issue347/browser', 'issue345/browser',
    'issue350/browser', 'issue349/browser', 'issue352/browser', 'issue351/browser',
    'mentions-inbox-browser-results', 'readonly-archive-browser-results')


def directories(component):
    data.require(component in ('web', 'flutter'))
    return WEB_ROOTS if component == 'web' else ('visual/flutter',)


def part_path(root, identity):
    return root / ('.out/ci/' + identity['component'] + '-parts/' + identity['profile'] + '.json')


def marker_path(root, identity):
    return root / ('.out/ci/capture-state/' + identity['component'] + '-' + identity['profile'] + '.json')


def begin(root, identity):
    data.identity(identity)
    root = Path(root)
    data.require(root.resolve() == root and root.is_dir())
    candidates = [root / '.out' / name for name in directories(identity['component'])]
    candidates += [part_path(root, identity), marker_path(root, identity)]
    data.require(all(not path.exists() and not path.is_symlink() for path in candidates))
    marker = marker_path(root, identity)
    data.require(marker.parent.resolve() == marker.parent)
    marker.parent.mkdir(parents=True, exist_ok=True)
    marker.write_text(json.dumps({'schema_version': 1, 'identity': identity}, sort_keys=True) + '\n')
    return marker


def started(root, identity):
    data.identity(identity)
    marker = marker_path(Path(root), identity)
    raw, _ = data.payload(marker, '.json')
    data.require(data.strict_json(raw) == {'schema_version': 1, 'identity': identity})


def collect(root, component):
    root = Path(root)
    data.require(root.resolve() == root and root.is_dir())
    files, ignored, visited = {}, 0, 0
    for name in directories(component):
        directory = root / '.out' / name
        data.require(directory.resolve() == directory and not directory.is_symlink())
        if not directory.exists(): continue
        data.require(directory.is_dir())
        pending = [directory]
        while pending:
            for path in pending.pop().iterdir():
                visited += 1
                data.require(visited <= MAX_ENTRIES)
                data.require(not path.is_symlink() and path.resolve() == path)
                if path.name.startswith('.'):
                    ignored += 1
                    continue
                if path.is_dir():
                    pending.append(path)
                else:
                    data.require(path.is_file())
                    if path.suffix not in ('.png', '.json'):
                        ignored += 1
                        continue
                    base = root / '.out' if component == 'web' else directory
                    logical = path.relative_to(base).as_posix()
                    data.logical_path(logical)
                    data.require(logical not in files and len(files) < data.MAX_FILES)
                    files[logical] = path
    return files, ignored


def complete(component, files):
    data.require((component == 'flutter' and set(files) == set(VISUALS))
                 or (component == 'web' and any(name.endswith('.png') for name in files)))
