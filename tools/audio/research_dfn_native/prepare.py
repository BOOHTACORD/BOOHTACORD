"""Prepare a pinned, instrumented libDF research checkout; never a release asset."""
import argparse
import hashlib
import subprocess
import tarfile
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
COMMIT = '7b14b895fe7fc42cab72b4a4c1e49c982bd6404b'
MODEL_SHA = 'c94d91f70911001c946e0fabb4aa9adc37045f45a03b56008cb0c8244cb63616'
LOCK_SHA = '67fbef75860cff0812f4660f6f95d55bba942818f43dac1d20bbcf3a3043be02'


def replace_once(text, old, new):
    if text.count(old) != 1:
        raise ValueError('Pinned source layout changed')
    return text.replace(old, new, 1)


def prepare_tree(root, *, instrumented=True):
    workspace = (root / 'Cargo.toml').read_text(encoding='utf-8')
    manifest = (root / 'libDF/Cargo.toml').read_text(encoding='utf-8')
    lib = (root / 'libDF/src/lib.rs').read_text(encoding='utf-8')
    workspace = replace_once(workspace, '  "pyDF",\n  "pyDF-data",\n  "ladspa",\n  "demo",\n', '')
    manifest = replace_once(manifest, '  "dep:hdf5",\n', '')
    manifest = replace_once(manifest, 'hdf5-static = ["hdf5?/static"]\n', '')
    manifest = replace_once(manifest, 'hdf5 = { optional = true, git = "https://github.com/aldanor/hdf5-rust.git", rev = "26046fb" }\n', '')
    allocator = 'mod research_alloc;\n' if instrumented else ''
    lib = replace_once(lib, '#![allow(dead_code)]\n', '#![allow(dead_code)]\n' + allocator + '#[cfg(feature = "capi")]\nmod research_safe;\n')
    lock = (HERE / 'Cargo.lock').read_bytes()
    if hashlib.sha256(lock).hexdigest() != LOCK_SHA:
        raise ValueError('Research Cargo.lock hash mismatch')
    for path, content in ((root / 'Cargo.toml', workspace), (root / 'libDF/Cargo.toml', manifest),
                          (root / 'libDF/src/lib.rs', lib)):
        path.write_text(content, encoding='utf-8', newline='\n')
    (root / 'Cargo.lock').write_bytes(lock)
    overlays = [('safe.rs', 'research_safe.rs')]
    if instrumented:
        overlays.append(('alloc.rs', 'research_alloc.rs'))
    for source, target in overlays:
        content = (HERE / source).read_text(encoding='utf-8')
        (root / 'libDF/src' / target).write_text(content, encoding='utf-8', newline='\n')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, required=True, help='Local upstream Git repository')
    parser.add_argument('--output', type=Path, required=True, help='New directory for research sources')
    parser.add_argument('--without-allocation-counter', action='store_true', help='Omit research allocator instrumentation')
    args = parser.parse_args()
    actual = subprocess.check_output(['git', '-C', str(args.source), 'rev-parse', COMMIT + '^{commit}'], text=True).strip()
    if actual != COMMIT or args.output.exists():
        raise ValueError('Pinned commit missing or output already exists')
    args.output.mkdir(parents=True, exist_ok=False)
    with tempfile.TemporaryFile() as archive:
        subprocess.run(['git', '-C', str(args.source), 'archive', '--format=tar', COMMIT], stdout=archive, check=True)
        archive.seek(0)
        with tarfile.open(fileobj=archive, mode='r:') as tar:
            tar.extractall(args.output, filter='data')
    model = args.output / 'models/DeepFilterNet3_onnx.tar.gz'
    if hashlib.sha256(model.read_bytes()).hexdigest() != MODEL_SHA:
        raise ValueError('Pinned research model hash mismatch')
    prepare_tree(args.output, instrumented=not args.without_allocation_counter)
    print('Prepared pinned research source; it is not a release build.')


if __name__ == '__main__':
    main()
