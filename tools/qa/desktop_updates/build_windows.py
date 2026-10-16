"""Build two real beta clients and an actual per-user Velopack bootstrap."""
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

from tools.ci.native.process import ROOT, output, require_version, run
from tools.build.desktop_updater.sdk import prepare
from tools.build.windows.imports import verify_runtime
from tools.build.windows.installer import prepare_packager
from tools.build.windows.plugins import configured_plugins
from tools.build.windows.runtime import retain_runtime


def main():
    if sys.platform != 'win32':
        raise RuntimeError('Native Windows builder required')
    require_version('flutter', json.loads(output('flutter', '--version', '--machine'))['frameworkVersion'])
    prepare('windows')
    client = ROOT / 'clients/flutter'
    run('flutter', 'pub', 'get', '--enforce-lockfile', cwd=client)
    packager = prepare_packager()
    destination = ROOT / '.out/issue337-windows-packages'
    destination.mkdir(parents=True, exist_ok=False)
    source = output('git', 'rev-parse', 'HEAD')
    for build, version, order in ((78, '1.0.43', 57), (79, '1.0.44', 58)):
        identity = {'APP_VERSION': version, 'APP_NATIVE_BUILD': str(build),
            'APP_RELEASE_ID': f'windows-qa337-r{order}', 'APP_RELEASE_ORDER': str(order),
            'APP_DISTRIBUTION': 'direct', 'APP_CHANNEL': 'beta'}
        with configured_plugins(client):
            run('flutter', 'build', 'windows', '--release', '--no-pub',
                '--target=integration_test/desktop_updates/windows_app.dart',
                '--build-name=' + version, '--build-number=' + str(build),
                *['--dart-define=' + key + '=' + value for key, value in identity.items()], cwd=client)
        release = client / 'build/windows/x64/runner/Release'
        for name in ('boohtacord_desktop.exe', 'flutter_windows.dll', 'libwebrtc.dll',
                     'velopack_libc.dll', 'BOOHTACORDRecovery.exe', 'data/flutter_assets'):
            if not (release / name).exists():
                raise RuntimeError('Incomplete native Windows QA package')
        retain_runtime(release)
        verify_runtime(release, Path(os.environ['SystemRoot']) / 'System32')
        shutil.copyfile(ROOT / 'tools/build/desktop_updater/licenses/Velopack-1.2.161.txt',
                        release / 'LICENSE-Velopack.txt')
        folder = destination / str(build)
        subprocess.run([str(packager), 'pack', '--packId', 'boohtacord_desktop',
            '--packVersion', version, '--packDir', str(release),
            '--mainExe', 'boohtacord_desktop.exe', '--channel', 'beta',
            '--packTitle', 'BOOHTACORD', '--packAuthors', 'BOOHTACORD',
            '--outputDir', str(folder), '--noPortable'], check=True)
        packages, installers = list(folder.glob('*-full.nupkg')), list(folder.glob('*Setup.exe'))
        if len(packages) != 1 or len(installers) != 1:
            raise RuntimeError('Native QA bootstrap or full package missing')
        hashes = {}
        for file in (*packages, *installers):
            with file.open('rb') as stream:
                hashes[file.name] = {'size': file.stat().st_size,
                                    'sha256': hashlib.file_digest(stream, 'sha256').hexdigest()}
        (folder / 'qa-identity.json').write_text(json.dumps({
            'source': source, 'identity': identity, 'files': hashes}, indent=2))
    (destination / 'QA-NOTES.txt').write_text(
        'Owned installed Windows 78-to-79 acceptance only. Never production/latest.\n'
        'Real release-mode Flutter and Velopack; separate QA entrypoint drives the shipping UI.\n'
        'Requires fresh local private configuration and a publisher-signed envelope.\n'
        'No private publisher key, API credentials or session is embedded.\n'
        'Windows Authenticode is not configured or claimed.\nSource: ' + source + '\n')


if __name__ == '__main__':
    main()
