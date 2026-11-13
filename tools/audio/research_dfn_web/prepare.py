"""Recreate pinned DeepFilterNet WASM research sources; not a release builder."""
import argparse
import hashlib
import subprocess
import tarfile
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
UPSTREAM = 'd375b2d8309e0935d165700c91da9de862a99c31'
PATCH_COMMIT = '7e00a1b7522f044a31776fddc249a97a98de94ed'
PATCH_SHA = '88c73ae73ac1aaa99a72e8795e7fd41a67f4cd0f7cb49c1f69aeb70fe8c4abc9'
MODEL_SHA = 'c94d91f70911001c946e0fabb4aa9adc37045f45a03b56008cb0c8244cb63616'
LOCK_SHA = '83b27804cbfbe8167d62b2f839bf4d3bbd4adb1ea1deecc9b35c97ee6e98aa0b'


def replace_once(text, old, new):
    if text.count(old) != 1:
        raise ValueError('Pinned source layout changed')
    return text.replace(old, new, 1)


def prepare_tree(root):
    workspace_path = root / 'Cargo.toml'
    manifest_path = root / 'libDF/Cargo.toml'
    workspace = workspace_path.read_text(encoding='utf-8')
    manifest = manifest_path.read_text(encoding='utf-8')
    workspace = replace_once(workspace, '  "pyDF",\n  "pyDF-data",\n  "ladspa",\n  "demo",\n', '')
    manifest = replace_once(manifest, '  "dep:hdf5",\n', '')
    manifest = replace_once(manifest, 'hdf5-static = ["hdf5?/static"]\n', '')
    manifest = replace_once(manifest, 'hdf5 = { optional = true, git = "https://github.com/aldanor/hdf5-rust.git", rev = "26046fb" }\n', '')
    manifest = replace_once(manifest, 'wasm-bindgen = { version = "0.2.87", optional = true }', 'wasm-bindgen = { version = "=0.2.118", optional = true }')
    manifest = replace_once(manifest, 'js-sys = { version = "0.3", optional = true }', 'js-sys = { version = "=0.3.95", optional = true }')
    lock = (HERE / 'Cargo.lock').read_bytes()
    if hashlib.sha256(lock).hexdigest() != LOCK_SHA:
        raise ValueError('Research Cargo.lock hash mismatch')
    workspace_path.write_text(workspace, encoding='utf-8', newline='\n')
    manifest_path.write_text(manifest, encoding='utf-8', newline='\n')
    (root / 'Cargo.lock').write_bytes(lock)
    (root / 'libDF/src/wasm.rs').write_bytes((HERE / 'wasm.rs').read_bytes())


def git(repo, *args):
    return subprocess.check_output(['git', '-c', 'safe.directory=' + str(repo.resolve()), '-C', str(repo), *args])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, required=True)
    parser.add_argument('--patch-source', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    if args.output.exists():
        raise ValueError('Output already exists')
    if git(args.source, 'rev-parse', UPSTREAM + '^{commit}').decode().strip() != UPSTREAM:
        raise ValueError('Pinned upstream commit missing')
    patch = git(args.patch_source, 'show', PATCH_COMMIT + ':scripts/deepfilternet-tract-0.23.patch')
    if hashlib.sha256(patch).hexdigest() != PATCH_SHA:
        raise ValueError('Patch hash mismatch')
    args.output.mkdir(parents=True, exist_ok=False)
    with tempfile.TemporaryFile() as archive:
        subprocess.run(['git', '-c', 'safe.directory=' + str(args.source.resolve()), '-C', str(args.source),
                        'archive', '--format=tar', UPSTREAM], stdout=archive, check=True)
        archive.seek(0)
        with tarfile.open(fileobj=archive, mode='r:') as tar:
            tar.extractall(args.output, filter='data')
    model = args.output / 'models/DeepFilterNet3_onnx.tar.gz'
    if hashlib.sha256(model.read_bytes()).hexdigest() != MODEL_SHA:
        raise ValueError('Pinned model hash mismatch')
    subprocess.run(['git', 'apply', '--whitespace=nowarn', '-'], cwd=args.output, input=patch, check=True)
    prepare_tree(args.output)
    print('Prepared pinned Web research source; not a release build.')


if __name__ == '__main__':
    main()
