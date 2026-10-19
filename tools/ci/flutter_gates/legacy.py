"""Execute the hash-verified original Dart/builder control on current app source."""
import hashlib
import json
import subprocess
import sys
from tools.ci.native.process import ROOT, run
from tools.build.client_identity import dart_defines, flutter_version_args

PATHS = ('tools/ci/native/flutter.py', 'tools/verify/android_kotlin/verify_android_kotlin_modes.sh',
         'tools/build/android/run.py', '.github/workflows/ci-flutter.yaml')


def reference():
    value = json.loads((ROOT / 'tools/ci/flutter_gates/baseline-v1.json').read_text())
    if (set(value) != {'schema_version', 'source_revision', 'files', 'operations'} or value['schema_version'] != 1
            or value['source_revision'] != 'f1b190383372e32581790a80fafae3aab33e13e7'
            or set(value['files']) != set(PATHS) or len(value['operations']) != 11):
        raise ValueError('Reviewed immutable monolithic native control required')
    return value


def original(path):
    value = reference()
    if path not in PATHS:
        raise ValueError('Unknown original native control source')
    data = subprocess.check_output(['git', 'show', value['source_revision'] + ':' + path], cwd=ROOT)
    if hashlib.sha256(data).hexdigest() != value['files'][path]:
        raise ValueError('Original native control source digest differs')
    return data


def frozen(path):
    """Hash-bound public source fixture for offline workflow policy/unit tests."""
    value = json.loads((ROOT / 'tools/ci/flutter_gates/baseline-sources-v1.json').read_text())
    expected = reference()
    if (value.get('schema_version') != 1 or value.get('source_revision') != expected['source_revision']
            or set(value.get('files', {})) != set(PATHS) or path not in PATHS):
        raise ValueError('Original native source fixture inventory differs')
    data = value['files'][path].encode()
    if hashlib.sha256(data).hexdigest() != expected['files'][path]:
        raise ValueError('Original native source fixture digest differs')
    return data


def invoke(path, package, expected, argv):
    namespace = {'__name__': package + '.ci_legacy_control', '__package__': package,
                 '__file__': str(ROOT / path)}
    exec(compile(original(path), str(ROOT / path), 'exec'), namespace)
    delegate = namespace['run']; completed = []

    def checked(*args, **kwargs):
        index = len(completed)
        if index >= len(expected) or (args, kwargs.get('cwd')) != expected[index][1:]:
            raise ValueError('Original native control command coverage differs')
        delegate(*args, **kwargs)
        completed.append(expected[index][0])

    namespace['run'] = checked
    previous = sys.argv
    try:
        sys.argv = argv
        namespace['main']()
    finally:
        sys.argv = previous
    if completed != [row[0] for row in expected]:
        raise ValueError('Original native control did not execute every command')
    return completed


def dart():
    app = ROOT / 'clients/flutter'
    operations = reference()['operations']
    commands = [(('python3', '-m', 'unittest', 'tools.verify.test_flutter_webrtc_public_headers'), None)]
    for directory in (app, app / 'packages/livekit_client', app / 'packages/flutter_webrtc'):
        commands.extend([(('flutter', 'pub', 'get', '--enforce-lockfile'), directory),
                         (('flutter', 'test', '--no-pub'), directory)])
    commands.append((('flutter', 'analyze', '--no-pub', '--no-fatal-infos'), app))
    expected = [(name, args, cwd) for name, (args, cwd) in zip(operations[:8], commands)]
    return invoke(PATHS[0], 'tools.ci.native', expected, ['native-legacy-dart'])


def kotlin():
    path = PATHS[1]
    if (ROOT / path).read_bytes().replace(b'\r\n', b'\n') != original(path):
        raise ValueError('Kotlin control differs from its unchanged original two-mode script')
    run('bash', path)
    return ['kotlin-modes']


def apk():
    app = ROOT / 'clients/flutter'
    expected = [('debug-dependencies', ('flutter', 'pub', 'get', '--enforce-lockfile'), app),
                ('debug-apk', ('flutter', 'build', 'apk', '--debug', *flutter_version_args('android'),
                               *dart_defines('android')), app)]
    return invoke(PATHS[2], 'tools.build.android', expected, ['native-legacy-apk', '--debug'])


if __name__ == '__main__':
    from .legacy_run import main
    main()
