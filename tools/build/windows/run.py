"""One Windows build command for local use and hosted CI."""
import json
import sys
from tools.ci.native.process import ROOT, client, output, require_version, run
from tools.release.native_artifact.manifest import write
from .plugins import configured_plugins
from tools.build.client_identity import dart_defines, flutter_version_args


def main():
    if sys.platform != 'win32': raise RuntimeError('Windows build requires a Windows host')
    require_version('flutter', json.loads(output('flutter', '--version', '--machine'))['frameworkVersion'])
    from tools.build.desktop_updater.sdk import prepare
    prepare('windows')
    flutter = client('flutter')
    run('flutter', 'pub', 'get', '--enforce-lockfile', cwd=flutter)
    with configured_plugins(flutter):
        run('flutter', 'build', 'windows', '--release', '--no-pub', *flutter_version_args('windows'), *dart_defines('windows'), cwd=flutter)
    release = flutter / 'build/windows/x64/runner/Release'
    for required in ('boohtacord_desktop.exe', 'flutter_windows.dll', 'libwebrtc.dll', 'data/flutter_assets'):
        if not (release / required).exists(): raise RuntimeError('Incomplete Windows release: ' + required)
    from tools.build.windows.runtime import retain_runtime
    retain_runtime(release)
    import shutil
    shutil.copyfile(ROOT / 'tools/build/desktop_updater/licenses/Velopack-1.2.161.txt', release / 'LICENSE-Velopack.txt')
    signing = json.loads(output('pwsh', '-NoProfile', '-File', str(ROOT / 'tools/build/windows/signature.ps1'),
                                '-Path', str(release / 'boohtacord_desktop.exe')))
    write(release, 'windows', ['x64'], 'boohtacord_desktop', signing)
    from tools.build.windows.installer import package
    package(release)
    print('Retained Windows artifact, checksums and measured signing metadata: ' + str(release))


if __name__ == '__main__': main()
