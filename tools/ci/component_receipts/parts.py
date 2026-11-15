"""Read separate source/run-scoped Web/backend archives without rewriting receipts."""
import json
from pathlib import Path
from .history import archive_pattern, select_archives, valid_attempt


def profile_execution(current, profiles, attempts, profile):
    if attempts is None:
        return current
    if set(attempts) != set(profiles):
        raise ValueError('Every original profile execution is mandatory')
    for value in attempts.values(): valid_attempt(value, current['run_attempt'])
    return {**current, 'run_attempt': attempts[profile]}


def read_parts(directory, kind, source, execution, profiles):
    root = Path(directory).absolute()
    if not root.is_dir() or root.is_symlink() or root.resolve() != root:
        raise ValueError('Profile receipt directory is absent or indirect')
    expected = {name + '.json' for name in profiles}
    if {path.name for path in root.iterdir()} == expected:
        selected = {p: (root, execution['run_attempt']) for p in profiles}
    else:
        pattern = archive_pattern(kind, source, execution['run_id'], execution.get('namespace', 'web'))
        selected = select_archives(root, profiles, execution['run_attempt'], pattern)
    rows = []
    for profile, (folder, _) in selected.items():
        if folder != root and {p.name for p in folder.iterdir()} != {profile + '.json'}:
            raise ValueError('Unexpected files in profile receipt archive')
        path = folder / (profile + '.json')
        if not path.is_file() or path.is_symlink() or not 0 < path.stat().st_size <= 65536:
            raise ValueError('Profile receipt is missing, indirect or oversized')
        row = json.loads(path.read_text(encoding='utf-8'))
        if not isinstance(row, dict) or row.get('profile') != profile:
            raise ValueError('Profile receipt and archive identity differ')
        rows.append(row)
    return rows, {profile: part[1] for profile, part in selected.items()}
