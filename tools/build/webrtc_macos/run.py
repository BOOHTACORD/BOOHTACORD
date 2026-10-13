"""Build the pinned, patched macOS SDK; run only focused real-route unit tests."""
import argparse
import ast
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[3]
RECIPE = Path(__file__).with_name('recipe.json')
PATCHES = ROOT / 'clients/flutter/packages/flutter_webrtc/third_party/patches'


def call(*args, cwd, env=None):
    subprocess.run([str(arg) for arg in args], cwd=cwd, env=env, check=True)


def output(*args, cwd):
    return subprocess.check_output([str(arg) for arg in args], cwd=cwd, text=True).strip()


def digest(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def checkout(directory, url, revision, branch=None):
    if not directory.exists():
        args = ['git', 'clone', '--depth', '1']
        if branch:
            args += ['--branch', branch]
        call(*args, url, directory, cwd=directory.parent)
    if output('git', 'rev-parse', 'HEAD', cwd=directory) != revision:
        call('git', 'fetch', '--depth', '1', 'origin', revision, cwd=directory)
        call('git', 'checkout', '--detach', revision, cwd=directory)
    if output('git', 'rev-parse', 'HEAD', cwd=directory) != revision:
        raise ValueError('SDK source/tool revision mismatch')


def build(args):
    recipe = json.loads(RECIPE.read_text())
    workspace = args.workspace.resolve()
    workspace.mkdir(parents=True, exist_ok=True)
    depot = workspace.parent / 'depot_tools'
    source = workspace / 'src'
    checkout(depot, 'https://chromium.googlesource.com/chromium/tools/depot_tools.git', recipe['depot_revision'])
    checkout(source, 'https://github.com/webrtc-sdk/webrtc.git', recipe['source_revision'], 'm150_release')
    env = dict(os.environ, DEPOT_TOOLS_UPDATE='0', PATH=str(depot) + os.pathsep + os.environ['PATH'])
    # Initialize the pinned Python shim used by gn/ninja without updating Git
    # or installing the unrelated lint-tool bootstrap set.
    call('bash', '-c', 'source "$1/bootstrap_python3"; bootstrap_python3',
         'sdk-bootstrap', depot, cwd=workspace, env=env)
    # The pinned tree's sole unnamed hook downloads benchmark video/audio.
    # These two routing tests use in-memory PCM and need no media fixtures.
    hooks = next(n.value.elts for n in ast.parse((source / 'DEPS').read_text()).body
                 if isinstance(n, ast.Assign) and any(isinstance(t, ast.Name) and t.id == 'hooks' for t in n.targets))
    unnamed = [h for h in hooks if 'name' not in [k.value for k in h.keys]]
    if len(unnamed) != 1 or 'chromium-webrtc-resources' not in ast.unparse(unnamed[0]):
        raise ValueError('Unexpected SDK resource hook; review the pinned recipe')
    configuration = "solutions = [{'name': 'src', 'url': 'https://github.com/webrtc-sdk/webrtc.git', 'managed': False, 'custom_deps': {}, 'custom_vars': {}, 'custom_hooks': [{'name': ''}]}]\ntarget_os = ['mac']\n"
    (workspace / '.gclient').write_text(configuration)
    if not args.synced:
        call(depot / 'gclient', 'sync', '--nohooks', '--no-history', '--shallow', '-j', '6', cwd=workspace, env=env)
    elif not (workspace / '.gclient_entries').is_file():
        raise ValueError('A completed owned dependency sync is required')
    call(depot / 'gclient', 'runhooks', cwd=workspace, env=env)
    patches = [PATCHES / f'webrtc-sdk-m150-custom-source-{kind}.patch' for kind in ('routing', 'regression')]
    for patch in patches:
        applied = subprocess.run(['git', 'apply', '--reverse', '--check', str(patch)], cwd=source, capture_output=True).returncode == 0
        if not applied:
            call('git', 'apply', '--check', patch, cwd=source)
            call('git', 'apply', patch, cwd=source)
    build_dir = workspace / ('build-' + args.arch)
    gn_args = recipe['gn_args'] + f' target_cpu="{args.arch}"'
    call(depot / 'gn', 'gen', build_dir, '--args=' + gn_args, cwd=source, env=env)
    jobs = str(min(4, os.cpu_count() or 2))
    call(depot / 'ninja', '-C', build_dir, '-j', jobs, 'mac_framework_bundle', cwd=source, env=env)
    if args.arch == 'arm64':
        call(depot / 'ninja', '-C', build_dir, '-j', jobs, 'audio_engine_tests', cwd=source, env=env)
        call(build_dir / 'audio_engine_tests', '--gtest_filter=AudioSendStreamTest.Boohtacord*', '--gtest_output=json:' + str(build_dir / 'routing-tests.json'), cwd=source)
        tests = json.loads((build_dir / 'routing-tests.json').read_text())
        if tests['tests'] != 2 or tests['failures'] != 0:
            raise ValueError('Both real native routing regressions must execute and pass')
    retained = args.output.resolve()
    retained.mkdir(parents=True, exist_ok=True)
    framework = build_dir / 'WebRTC.framework'
    binary = framework / 'WebRTC'
    symbols = output('xcrun', 'nm', '-gU', binary, cwd=source)
    if '_BoohtacordScreenAudioRoutingRevision' not in symbols:
        raise ValueError('Patched routing marker missing from actual SDK binary')
    archive = retained / ('WebRTC-' + args.arch + '.framework.zip')
    call('/usr/bin/ditto', '-c', '-k', '--sequesterRsrc', '--keepParent', framework, archive, cwd=source)
    receipt = {'source_revision': recipe['source_revision'], 'depot_revision': recipe['depot_revision'],
               'version': recipe['version'], 'architecture': args.arch, 'gn_args': gn_args,
               'routing_marker': recipe['routing_marker'], 'patches': {p.name: digest(p) for p in patches},
               'framework_binary_sha256': digest(binary), 'archive_sha256': digest(archive),
               'native_route_tests': 'PASS' if args.arch == 'arm64' else 'NOT_RUN',
               'physical_playback_smoke': 'NOT_RUN'}
    (retained / ('sdk-' + args.arch + '.json')).write_text(json.dumps(receipt, indent=2) + '\n')
    if args.arch == 'arm64':
        shutil.copy2(build_dir / 'routing-tests.json', retained / 'routing-tests.json')
    shutil.copy2(source / 'LICENSE', retained / 'LICENSE-WebRTC.txt')


def assemble(args):
    destination = args.output.resolve()
    destination.mkdir(parents=True, exist_ok=True)
    recipe = json.loads(RECIPE.read_text())
    frameworks = []
    receipts = []
    for arch in recipe['architectures']:
        inputs = args.inputs.resolve() / arch
        receipt = json.loads((inputs / ('sdk-' + arch + '.json')).read_text())
        archive = inputs / ('WebRTC-' + arch + '.framework.zip')
        if digest(archive) != receipt['archive_sha256'] or receipt['source_revision'] != recipe['source_revision']:
            raise ValueError('SDK architecture receipt mismatch')
        call('/usr/bin/ditto', '-x', '-k', archive, inputs, cwd=destination)
        frameworks.append(inputs / 'WebRTC.framework')
        receipts.append(receipt)
    if receipts[0]['native_route_tests'] != 'PASS' or receipts[0]['patches'] != receipts[1]['patches']:
        raise ValueError('SDK focused regression/patch mismatch')
    universal = destination / 'universal/WebRTC.framework'
    universal.parent.mkdir()
    shutil.copytree(frameworks[0], universal, symlinks=True)
    binary = universal / 'WebRTC'
    if binary.is_symlink():
        binary = binary.resolve()
    call('xcrun', 'lipo', '-create', *(p / 'WebRTC' for p in frameworks), '-output', binary, cwd=destination)
    xcframework = destination / 'WebRTC.xcframework'
    call('xcodebuild', '-create-xcframework', '-framework', universal, '-output', xcframework, cwd=destination)
    mac_framework = xcframework / 'macos-arm64_x86_64/WebRTC.framework'
    mac_binary = mac_framework / 'WebRTC'
    # Match upstream's framework layout, retaining the universal file in A.
    if not mac_binary.is_symlink() and (mac_framework / 'Versions/A').is_dir():
        shutil.move(mac_binary, mac_framework / 'Versions/A/WebRTC')
        mac_binary.symlink_to('Versions/Current/WebRTC')
    shutil.copy2(args.inputs / 'arm64/LICENSE-WebRTC.txt', xcframework / 'LICENSE')
    archive = destination / 'WebRTC-macos.xcframework.zip'
    call('/usr/bin/ditto', '-c', '-k', '--sequesterRsrc', '--keepParent', xcframework, archive, cwd=destination)
    receipt = {'version': recipe['version'], 'source_revision': recipe['source_revision'],
               'routing_marker': recipe['routing_marker'], 'architectures': receipts,
               'xcframework_sha256': digest(archive), 'physical_playback_smoke': 'NOT_RUN'}
    (destination / 'sdk-manifest.json').write_text(json.dumps(receipt, indent=2) + '\n')
    (destination / 'SHA256SUMS').write_text(f'{digest(archive)}  {archive.name}\n')
    print(json.dumps({'version': recipe['version'], 'checksum': digest(archive)}))


def main():
    if sys.platform != 'darwin':
        raise RuntimeError('Apple SDK build requires macOS')
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='command', required=True)
    b = sub.add_parser('build')
    b.add_argument('--arch', choices=['arm64', 'x64'], required=True)
    b.add_argument('--workspace', type=Path, required=True)
    b.add_argument('--output', type=Path, required=True)
    b.add_argument('--synced', action='store_true')
    a = sub.add_parser('assemble')
    a.add_argument('--inputs', type=Path, required=True)
    a.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    (build if args.command == 'build' else assemble)(args)


if __name__ == '__main__':
    main()
