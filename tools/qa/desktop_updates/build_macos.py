"""Build a beta-only real app for the installed macOS acceptance journey."""
import shutil
import subprocess
import sys
from pathlib import Path

from tools.ci.native.process import ROOT
from tools.build.desktop_updater.sdk import prepare
from tools.build.desktop_updater.recovery import macos


def main():
    if sys.platform != 'darwin':
        raise RuntimeError('A native macOS host is required')
    prepare('macos')
    client = ROOT / 'clients/flutter'
    identity = {'APP_VERSION': '1.0.44', 'APP_NATIVE_BUILD': '79',
                'APP_RELEASE_ID': 'macos-qa337-r58', 'APP_RELEASE_ORDER': '58',
                'APP_DISTRIBUTION': 'direct', 'APP_CHANNEL': 'beta'}
    subprocess.run(['flutter', 'build', 'macos', '--release', '--no-pub',
                    '--target=integration_test/desktop_updates/native_app.dart',
                    '--build-name=1.0.44', '--build-number=79',
                    *['--dart-define=' + key + '=' + value for key, value in identity.items()]],
                   cwd=client, check=True)
    app = client / 'build/macos/Build/Products/Release/BOOHTACORD.app'
    resources = app / 'Contents/Resources'
    helper = macos()
    shutil.copytree(helper, resources / helper.name, dirs_exist_ok=True)
    shutil.copyfile(ROOT / 'tools/build/desktop_updater/licenses/Sparkle-2.10.0.txt',
                    resources / 'LICENSE-Sparkle.txt')
    output = ROOT / '.out/issue337-macos-acceptance'
    subprocess.run(['bash', str(ROOT / 'tools/build/macos/package.sh'), str(app),
                    'macos-v1.0.44', str(output)], check=True)
    # No private QA configuration, publisher key, session or password is included.
    (output / 'QA-NOTES.txt').write_text(
        'Disposable macOS updater acceptance package for #337, not production.\n'
        'Version 1.0.44 (79), macos-qa337-r58, order 58, direct/beta.\n'
        'Universal app; ad-hoc signed, not Developer ID/notarized.\n'
        'Uses integration_test/desktop_updates/native_app.dart with the shipping app.\n'
        'Requires an owned local private acceptance configuration outside the bundle.\n'
        'No credentials or private signing key are embedded. No production catalog promotion.\n')


if __name__ == '__main__':
    main()
