"""Independent Dart and Android checks; each runner owns its dependency state."""
import json
import os
from tools.ci.native.process import ROOT, VERSIONS, client, output, require_version, run
from tools.ci.flutter_setup.vendor_locks import prepare
from tools.ci.flutter_setup.metadata import check_machine

OPERATIONS = {
    'dart': ('public-headers', 'app-dependencies', 'app-tests', 'livekit-locks',
             'livekit-dependencies', 'livekit-tests', 'webrtc-locks',
             'webrtc-dependencies', 'webrtc-tests', 'app-analysis'),
    'android': ('app-dependencies', 'debug-apk'),
    'android-kotlin': ('app-dependencies', 'kotlin-modes'),
}


def test_command(env):
    del env  # Flutter's default process count follows the runner's available CPUs.
    return ('flutter', 'test', '--no-pub')


def execute(profile):
    if profile not in OPERATIONS:
        raise ValueError('Unknown Flutter CI profile')
    machine = json.loads(output('flutter', '--version', '--machine'))
    require_version('flutter', machine['frameworkVersion'])
    require_version('dart', machine['dartSdkVersion'].split()[0])
    sdk_source = json.loads((ROOT / 'tools/ci/flutter_setup/source.json').read_text())
    check_machine(machine, {'version': VERSIONS['flutter'], 'dart_version': VERSIONS['dart'],
                            'framework_revision': sdk_source['framework_revision']})
    app = client('flutter')
    completed = []

    def command(name, *args, **kwargs):
        run(*args, **kwargs)
        completed.append(name)

    if profile == 'dart':
        command('public-headers', 'python3', '-m', 'unittest', 'tools.verify.test_flutter_webrtc_public_headers')
    command('app-dependencies', 'flutter', 'pub', 'get', '--enforce-lockfile', cwd=app)
    if profile == 'android-kotlin':
        # The existing script exercises legacy KGP and AGP built-in Kotlin.
        command('kotlin-modes', 'bash', 'tools/verify/android_kotlin/verify_android_kotlin_modes.sh')
    elif profile == 'android':
        command('debug-apk', 'python3', '-m', 'tools.build.android.run', '--debug', '--no-pub')
    else:
        command('app-tests', *test_command(os.environ), cwd=app)
        for package, prefix in (('livekit_client', 'livekit'), ('flutter_webrtc', 'webrtc')):
            prepare(ROOT, package)
            completed.append(prefix + '-locks')
            path = app / 'packages' / package
            command(prefix + '-dependencies', 'flutter', 'pub', 'get', '--enforce-lockfile', cwd=path)
            command(prefix + '-tests', *test_command(os.environ), cwd=path)
        command('app-analysis', 'flutter', 'analyze', '--no-pub', '--no-fatal-infos', cwd=app)
    if completed != list(OPERATIONS[profile]):
        raise ValueError('Incomplete Flutter CI operation inventory')
    return completed
