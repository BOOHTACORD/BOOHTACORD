"""Persist completed real control phases across the original upload/build order."""
import argparse
import json
import math
import os
import re
import time
from tools.ci.native.process import ROOT
from . import artifacts, legacy, results, source


def state_at(path, revision, identity):
    try:
        if path.is_symlink() or not path.is_file() or not 0 < path.stat().st_size <= 65536:
            raise ValueError('Original control phases are missing')
        value = json.loads(path.read_text())
        if (set(value) != {'source_revision', 'execution', 'completed', 'started'}
                or value['source_revision'] != revision or value['execution'] != identity
                or not isinstance(value['completed'], list) or type(value['started']) not in (int, float)
                or not math.isfinite(value['started']) or value['started'] <= 0):
            raise ValueError('Original control phase state is stale or malformed')
        return value
    except (OSError, json.JSONDecodeError, TypeError, KeyError) as error:
        raise ValueError('Original control phase state is unavailable') from error


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('phase', choices=('dart', 'kotlin', 'apk', 'finish'))
    args = parser.parse_args()
    directory = ROOT / '.out/ci'
    if directory.resolve() != directory:
        raise ValueError('Indirect legacy CI result directory rejected')
    directory.mkdir(parents=True, exist_ok=True)
    target, state = directory / 'flutter-legacy.json', directory / 'flutter-legacy-state.json'
    if target.is_symlink() or state.is_symlink():
        raise ValueError('Indirect legacy CI result rejected')
    target.write_text('{"status":"FAIL"}\n')
    revision, run_id, attempt, namespace = source.context(os.environ)
    if not re.fullmatch('shadow-old-[123]', namespace):
        raise ValueError('Explicit finite legacy shadow namespace required')
    identity = {'run_id': run_id, 'run_attempt': attempt, 'namespace': namespace}
    source.verify(revision)
    if args.phase == 'dart':
        capture = ROOT / '.out/visual/flutter'
        if capture.exists() or (ROOT / '.out/native/android-debug').exists():
            raise ValueError('Legacy control requires fresh artifact directories')
        os.environ['BOOHTACORD_VISUAL_CAPTURE_DIR'] = str(capture)
        value = {'source_revision': revision, 'execution': identity, 'completed': [], 'started': time.perf_counter()}
        state.write_text(json.dumps(value) + '\n')
    else:
        value = state_at(state, revision, identity)
    expected = legacy.reference()['operations']
    prefix = {'dart': 0, 'kotlin': 8, 'apk': 9, 'finish': 11}[args.phase]
    if value['completed'] != expected[:prefix]:
        raise ValueError('Original control phases are incomplete, duplicated or reordered')
    if args.phase != 'finish':
        completed = {'dart': legacy.dart, 'kotlin': legacy.kotlin, 'apk': legacy.apk}[args.phase]()
        source.verify(revision)
        value['completed'].extend(completed)
        state.write_text(json.dumps(value) + '\n')
        return
    measured = {'dart': artifacts.visuals(ROOT / '.out/visual/flutter'),
                'android': artifacts.android(ROOT / '.out/native/android-debug', revision)}
    source.verify(revision)
    seconds = time.perf_counter() - value['started']
    if not math.isfinite(seconds) or not 0 < seconds < 3600:
        raise ValueError('Original native execution duration is invalid')
    part = {'schema_version': 1, 'source_revision': revision, 'status': 'PASS', 'execution': identity,
            'sdk': results.expected_sdk(), 'baseline': legacy.reference(), 'operations': value['completed'],
            'seconds': seconds, 'artifacts': measured}
    target.write_text(json.dumps(part, indent=2, sort_keys=True) + '\n')
    print('PASS: every original Dart/vendor/analyze/Kotlin/debug-build command and required artifact')
