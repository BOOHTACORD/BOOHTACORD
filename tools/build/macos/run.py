"""Build the ordinary macOS release with the shared native release identity."""
import json
import os
import sys
from tools.ci.native.process import client, output, require_version, run
from tools.build.client_identity import dart_defines, flutter_version_args, load


def main():
    if sys.platform != 'darwin':
        raise RuntimeError('macOS build requires a macOS host')
    require_version('flutter', json.loads(output('flutter', '--version', '--machine'))['frameworkVersion'])
    from tools.build.desktop_updater.sdk import prepare
    prepare('macos')
    identity = load('macos')
    tag = 'macos-v' + identity['version']
    if os.environ.get('GITHUB_REF_TYPE') == 'tag' and os.environ.get('GITHUB_REF_NAME') != tag:
        raise ValueError('Release tag differs from the native client identity')
    run('flutter', 'build', 'macos', '--release', '--no-pub',
        *flutter_version_args('macos'), *dart_defines('macos'), cwd=client('flutter'))
    from tools.build.desktop_updater.recovery import macos
    import shutil
    helper = macos()
    resources = client('flutter') / 'build/macos/Build/Products/Release/BOOHTACORD.app/Contents/Resources'
    shutil.copytree(helper, resources / helper.name, dirs_exist_ok=True)


if __name__ == '__main__':
    main()
