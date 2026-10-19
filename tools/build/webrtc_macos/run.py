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
import time
from . import contract,execution
from .extract import extract
from tools.ci.macos.host import inspect

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
    started=time.monotonic();recipe=json.loads(RECIPE.read_text());toolchain=inspect(args.arch)
    contract.require(not args.synced)
    workspace=args.workspace.resolve();identity=execution.own(workspace,args.arch)
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
    contract.require(output('git','rev-parse','HEAD',cwd=source)==recipe['source_revision'])
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
    call(depot / 'ninja', '-C', build_dir, '-j', jobs, 'audio_engine_tests', cwd=source, env=env)
    call(build_dir / 'audio_engine_tests', '--gtest_filter=AudioSendStreamTest.Boohtacord*', '--gtest_output=json:' + str(build_dir / 'routing-tests.json'), cwd=source)
    tests=json.loads((build_dir/'routing-tests.json').read_text())
    contract.require(tests.get('tests')==2 and all(tests.get(key)==0 for key in ('failures','disabled','errors')))
    retained = args.output.resolve()
    retained.mkdir(parents=True, exist_ok=False)
    framework = build_dir / 'WebRTC.framework'
    binary = framework / 'WebRTC'
    binary_arch=output('xcrun','lipo','-archs',binary,cwd=source).split()
    contract.require(binary_arch==['arm64' if args.arch=='arm64' else 'x86_64'])
    symbols = output('xcrun', 'nm', '-gU', binary, cwd=source)
    if '_BoohtacordScreenAudioRoutingRevision' not in symbols:
        raise ValueError('Patched routing marker missing from actual SDK binary')
    archive = retained / ('WebRTC-' + args.arch + '.framework.zip')
    call('/usr/bin/ditto', '-c', '-k', '--sequesterRsrc', '--keepParent', framework, archive, cwd=source)
    receipt=dict(contract.inputs(),**identity,architecture=args.arch,gn_args=gn_args,toolchain=toolchain,
                 framework_binary_sha256=digest(binary),archive_sha256=digest(archive),binary_architectures=binary_arch,
                 native_route_tests='PASS',native_test_count=2,native_test_report_sha256=digest(build_dir/'routing-tests.json'),
                 physical_playback_smoke='NOT_RUN',owned_workspace_removed=False,seconds=round(time.monotonic()-started,3))
    (retained/('sdk-'+args.arch+'.json')).write_text(json.dumps(receipt,sort_keys=True)+'\n')
    shutil.copy2(build_dir/'routing-tests.json',retained/'routing-tests.json')
    shutil.copy2(source / 'LICENSE', retained / 'LICENSE-WebRTC.txt')


def assemble(args):
    started=time.monotonic();identity=execution.context();inspect('arm64')
    destination=args.output.resolve();destination.mkdir(parents=True,exist_ok=False)
    recipe=json.loads(RECIPE.read_text());frameworks=[];receipts=[]
    for arch in recipe['architectures']:
        inputs=args.inputs.resolve()/arch
        receipt=json.loads((inputs/('sdk-'+arch+'.json')).read_text())
        contract.validate_slice(receipt,arch,identity['builder_revision'],identity['run_id'],identity['run_attempt'])
        archive=inputs/('WebRTC-'+arch+'.framework.zip')
        contract.require(digest(archive)==receipt['archive_sha256'] and receipt.get('owned_workspace_removed') is True)
        tests=inputs/'routing-tests.json';contract.require(digest(tests)==receipt['native_test_report_sha256'])
        value=json.loads(tests.read_text());contract.require(value.get('tests')==2 and all(value.get(k)==0 for k in ('failures','disabled','errors')))
        framework=extract(archive,inputs/'extracted');binary=framework/'WebRTC'
        contract.require(digest(binary)==receipt['framework_binary_sha256']
                         and output('xcrun','lipo','-archs',binary,cwd=destination).split()==receipt['binary_architectures'])
        frameworks.append(framework);receipts.append(receipt)
    contract.validate_matrix(receipts,identity['builder_revision'],identity['run_id'],identity['run_attempt'])
    universal = destination / 'universal/WebRTC.framework'
    universal.parent.mkdir()
    shutil.copytree(frameworks[0], universal, symlinks=True)
    binary = universal / 'WebRTC'
    if binary.is_symlink():
        binary = binary.resolve()
    call('xcrun', 'lipo', '-create', *(p / 'WebRTC' for p in frameworks), '-output', binary, cwd=destination)
    xcframework = destination / 'WebRTC.xcframework'
    contract.require(set(output('xcrun','lipo','-archs',binary,cwd=destination).split())=={'arm64','x86_64'})
    call('xcodebuild', '-create-xcframework', '-framework', universal, '-output', xcframework, cwd=destination)
    mac_framework = xcframework / 'macos-arm64_x86_64/WebRTC.framework'
    mac_binary = mac_framework / 'WebRTC'
    # Match upstream's framework layout, retaining the universal file in A.
    if not mac_binary.is_symlink() and (mac_framework / 'Versions/A').is_dir():
        shutil.move(mac_binary, mac_framework / 'Versions/A/WebRTC')
        mac_binary.symlink_to('Versions/Current/WebRTC')
    shutil.copy2(args.inputs / 'arm64/LICENSE-WebRTC.txt', xcframework / 'LICENSE')
    call('/usr/bin/codesign','--force','--sign','-',mac_framework,cwd=destination)
    call('/usr/bin/codesign','--verify','--deep','--strict',mac_framework,cwd=destination)
    archive = destination / 'WebRTC-macos.xcframework.zip'
    call('/usr/bin/ditto', '-c', '-k', '--sequesterRsrc', '--keepParent', xcframework, archive, cwd=destination)
    receipt=dict(contract.inputs(),**identity,architectures=receipts,xcframework_sha256=digest(archive),
                 universal_binary_sha256=digest(mac_binary),signing='adhoc-framework-not-notarized',physical_playback_smoke='NOT_RUN',seconds=round(time.monotonic()-started,3))
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
