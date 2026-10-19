"""One Windows build command for local use and hosted CI."""
import argparse
import json
import sys
from pathlib import Path
from tools.ci.native.process import ROOT, client, output, require_version, run
from tools.release.native_artifact.manifest import write
from .plugins import configured_plugins
from tools.build.client_identity import dart_defines, flutter_version_args


def main():
    if sys.platform != 'win32': raise RuntimeError('Windows build requires a Windows host')
    parser = argparse.ArgumentParser()
    parser.add_argument('--ci-acceptance', action='store_true')
    args = parser.parse_args()
    if args.ci_acceptance:
        import os
        if os.environ.get('GITHUB_ACTIONS') != 'true' or os.environ.get('RUNNER_ENVIRONMENT') != 'github-hosted':
            raise RuntimeError('CI acceptance builds require a disposable hosted runner')
    require_version('flutter', json.loads(output('flutter', '--version', '--machine'))['frameworkVersion'])
    from tools.build.desktop_updater.sdk import prepare
    prepare('windows')
    flutter = client('flutter')
    run('flutter', 'pub', 'get', '--enforce-lockfile', cwd=flutter)
    with configured_plugins(flutter):
        run('flutter', 'build', 'windows', '--release', '--no-pub', *flutter_version_args('windows'), *dart_defines('windows'),
            *(['--target=integration_test/screen_setup_windows_app.dart'] if args.ci_acceptance else []), cwd=flutter)
    release = flutter / 'build/windows/x64/runner/Release'
    for required in ('boohtacord_desktop.exe', 'flutter_windows.dll', 'libwebrtc.dll', 'data/flutter_assets'):
        if not (release / required).exists(): raise RuntimeError('Incomplete Windows release: ' + required)
    from tools.build.windows.runtime import retain_runtime
    retain_runtime(release)
    import os
    from tools.build.windows.imports import verify_runtime
    verify_runtime(release, Path(os.environ['SystemRoot']) / 'System32')
    import shutil
    shutil.copyfile(ROOT / 'tools/build/desktop_updater/licenses/Velopack-1.2.161.txt', release / 'LICENSE-Velopack.txt')
    marker = release / 'ci-purpose.json'
    if args.ci_acceptance:
        from tools.ci.windows_gates.transfer import PURPOSE
        marker.write_text(json.dumps(PURPOSE, sort_keys=True) + '\n', encoding='utf-8')
    else:
        marker.unlink(missing_ok=True)
    signing = json.loads(output('pwsh', '-NoProfile', '-File', str(ROOT / 'tools/build/windows/signature.ps1'),
                                '-Path', str(release / 'boohtacord_desktop.exe')))
    write(release, 'windows', ['x64'], 'boohtacord_desktop', signing)
    from tools.build.windows.installer import package
    package(release)
    print('Retained Windows artifact, checksums and measured signing metadata: ' + str(release))


if __name__ == '__main__': main()
