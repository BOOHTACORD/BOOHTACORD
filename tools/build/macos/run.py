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
    identity = load('macos')
    tag = 'macos-v' + identity['version']
    if os.environ.get('GITHUB_REF_NAME', tag) != tag:
        raise ValueError('Release tag differs from the native client identity')
    run('flutter', 'build', 'macos', '--release', '--no-pub',
        *flutter_version_args('macos'), *dart_defines('macos'), cwd=client('flutter'))


if __name__ == '__main__':
    main()
