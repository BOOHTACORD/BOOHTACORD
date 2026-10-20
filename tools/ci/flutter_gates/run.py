"""Execute one isolated profile; retain explicit failure before any native command."""
import argparse
import json
import os
import time
from tools.ci.native.process import ROOT
from . import artifacts, profiles, results, source


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('profile', choices=profiles.OPERATIONS)
    args = parser.parse_args()
    directory = ROOT / '.out/ci/flutter-parts'
    if directory.resolve() != directory:
        raise ValueError('Indirect native CI result directory rejected')
    directory.mkdir(parents=True, exist_ok=True)
    target = directory / (args.profile + '.json')
    if target.is_symlink():
        raise ValueError('Indirect native CI result rejected')
    target.write_text(json.dumps({'status': 'FAIL', 'profile': args.profile}) + '\n')
    started = time.perf_counter()
    revision, run_id, attempt, namespace = source.context(os.environ)
    source.verify(revision)
    if args.profile == 'dart':
        capture = ROOT / '.out/visual/flutter'
        if capture.exists():
            raise ValueError('Native visual captures require a fresh profile directory')
        os.environ['BOOHTACORD_VISUAL_CAPTURE_DIR'] = str(capture)
    elif args.profile == 'android' and (ROOT / '.out/native/android-debug').exists():
        raise ValueError('Debug APK requires a fresh profile directory')
    completed = profiles.execute(args.profile)
    source.verify(revision)
    measured = (artifacts.visuals(capture) if args.profile == 'dart' else
                artifacts.android(ROOT / '.out/native/android-debug', revision) if args.profile == 'android' else {})
    part = {'schema_version': 1, 'profile': args.profile, 'source_revision': revision,
            'run_id': run_id, 'run_attempt': attempt, 'namespace': namespace, 'status': 'PASS', 'completed': completed,
            'seconds': time.perf_counter() - started, 'sdk': results.expected_sdk(), 'artifacts': measured}
    target.write_text(json.dumps(part, indent=2, sort_keys=True) + '\n')
    print('PASS: complete ' + args.profile + ' profile and mandatory public artifacts')


if __name__ == '__main__':
    main()
