"""Fail closed on missing, failed, stale or partial Flutter/Android evidence."""
import json
import os
from tools.ci.native.process import ROOT
from . import results, source


def main():
    directory = ROOT / '.out/ci/flutter-parts'
    revision, run_id, attempt, namespace = source.context(os.environ)
    source.verify(revision)
    if directory.is_symlink() or directory.resolve() != directory or not directory.is_dir():
        raise ValueError('Native profile results are missing or indirect')
    paths = list(directory.iterdir())
    if {p.name for p in paths} != {'dart.json', 'android.json'}:
        raise ValueError('Exactly the two current native profile results are mandatory')
    parts = []
    for path in sorted(paths):
        if path.is_symlink() or not path.is_file() or not 0 < path.stat().st_size <= 64 * 1024:
            raise ValueError('Native profile result is missing, indirect or oversized')
        value = json.loads(path.read_text(encoding='utf-8'))
        if value.get('profile') + '.json' != path.name:
            raise ValueError('Native result profile and filename differ')
        parts.append(value)
    results.validate(parts, json.loads(os.environ['FLUTTER_NEEDS']), revision, run_id, attempt, namespace)
    print('PASS: Dart/vendor/analyze/visual and Android Kotlin/APK gates on this source and run attempt')


if __name__ == '__main__':
    main()
