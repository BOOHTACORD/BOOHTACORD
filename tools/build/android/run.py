"""Shared Android build, identity verification and retained distribution metadata."""
import argparse
import json
import os
import shutil
from tools.ci.native.process import ROOT, client, output, require_version, run
from tools.release.native_artifact.manifest import version, write
from .signature import APPLICATION, inspect
from .signing import provision
from .apk_size.inspect import inspect_size
from tools.build.client_identity import dart_defines, flutter_version_args


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--debug', action='store_true')
    args = parser.parse_args()
    require_version('flutter', json.loads(output('flutter', '--version', '--machine'))['frameworkVersion'])
    flutter = client('flutter')
    native_version = version('android')
    tag = 'android-v' + native_version.split('+')[0]
    if not args.debug and os.environ.get('GITHUB_REF_NAME', tag) != tag: raise ValueError('Release tag differs from pubspec version')
    run('flutter', 'pub', 'get', '--enforce-lockfile', cwd=flutter)
    command = ('--debug',) if args.debug else ('--release', '--split-per-abi')
    with provision():
        # Flutter regenerates the release-only plugin registrant only with pub
        # enabled; --no-pub leaves dev plugins from the preceding pub get.
        run('flutter', 'build', 'apk', *command, *flutter_version_args('android'), *dart_defines('android'), cwd=flutter)
    destination = ROOT / '.out/native/android-debug' if args.debug else flutter / 'build/release-assets'
    destination.mkdir(parents=True, exist_ok=True)
    architectures = ['universal'] if args.debug else ['arm64-v8a', 'armeabi-v7a', 'x86_64']
    expected = {'app-debug.apk'} if args.debug else {f'BOOHTACORD-{tag}-{abi}.apk' for abi in architectures}
    if any(path.name not in expected | {'artifact-manifest.json', 'SHA256SUMS', 'LICENSE-RNNoise.txt', 'rnnoise-component.cdx.json'} for path in destination.iterdir()):
        raise ValueError('Artifact directory contains another release; choose a clean build workspace')
    inspected = {}
    for architecture in architectures:
        name = 'app-debug.apk' if args.debug else f'app-{architecture}-release.apk'
        source = flutter / 'build/app/outputs/flutter-apk' / name
        if not source.is_file() or not source.stat().st_size: raise RuntimeError('Missing APK: ' + name)
        if not args.debug and source.stat().st_size > 95000000: raise ValueError('APK exceeds the 95 MB release safety ceiling')
        info = inspect(source, release=not args.debug, version=native_version)
        info['size'] = inspect_size(source, release=not args.debug, architecture=architecture)
        retained = name if args.debug else f'BOOHTACORD-{tag}-{architecture}.apk'
        shutil.copyfile(source, destination / retained)
        inspected[retained] = info
    fingerprints = {item['certificate_sha256'] for item in inspected.values()}
    if len(fingerprints) != 1: raise ValueError('APK signers disagree')
    write(destination, 'android', architectures, APPLICATION, {
        'status': 'debug' if args.debug else 'signed', 'certificate_sha256': fingerprints.pop(), 'apks': inspected})
    print('Retained Android distribution, checksums and signer metadata: ' + str(destination))


if __name__ == '__main__': main()
