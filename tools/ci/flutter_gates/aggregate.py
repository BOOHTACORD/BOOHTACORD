"""Fail closed on missing, failed, stale or partial Flutter/Android evidence."""
import json
import os
from tools.ci.native.process import ROOT
from tools.ci.component_receipts.history import archive_pattern, select_archives
from . import profiles, results, source


def read_parts(directory, revision, run_id, attempt, namespace):
    if directory.is_symlink() or directory.resolve() != directory or not directory.is_dir():
        raise ValueError('Native profile results are missing or indirect')
    paths = list(directory.iterdir())
    expected = {name + '.json' for name in profiles.OPERATIONS}
    if {p.name for p in paths} == expected:
        selected = {profile: (directory, attempt) for profile in profiles.OPERATIONS}
    else:
        selected = select_archives(directory, list(profiles.OPERATIONS), attempt,
                                   archive_pattern('flutter', revision, run_id, namespace))
    parts = []
    for profile, (folder, _) in selected.items():
        if folder != directory and {p.name for p in folder.iterdir()} != {profile + '.json'}:
            raise ValueError('Native receipt archive contains unexpected files')
        path = folder / (profile + '.json')
        if path.is_symlink() or not path.is_file() or not 0 < path.stat().st_size <= 64 * 1024:
            raise ValueError('Native profile result is missing, indirect or oversized')
        value = json.loads(path.read_text(encoding='utf-8'))
        if value.get('profile') + '.json' != path.name:
            raise ValueError('Native result profile and filename differ')
        parts.append(value)
    return parts, {profile: receipt[1] for profile, receipt in selected.items()}


def main():
    revision, run_id, attempt, namespace = source.context(os.environ)
    source.verify(revision)
    parts, attempts = read_parts(ROOT / '.out/ci/flutter-parts', revision, run_id, attempt, namespace)
    results.validate(parts, json.loads(os.environ['FLUTTER_NEEDS']), revision, run_id, attempt, namespace,
                     attempts=attempts)
    print('PASS: complete native profiles on this source/run; original execution attempts preserved')


if __name__ == '__main__':
    main()
