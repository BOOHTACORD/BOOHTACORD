"""Build a pinned DeepFilter WASM research bundle in a new directory."""
import argparse
import hashlib
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path
from . import prepare

EXPECTED_WASM = '0745651e0b7a0993e8a4d71320840d28754c112425906b6f0e93f4c770724fec'
EXPECTED_GLUE = '1e6adbcb777c92a03b09051f8f43b76a382f3e0489e4ff38ec4a9ebbbae75979'
ROOT = Path(__file__).resolve().parents[3]


def check_version(command, prefix):
    value = subprocess.check_output([str(command), '--version']).decode().strip()
    if not (value == prefix or value.startswith(prefix + ' ')):
        raise ValueError('Unexpected tool version: ' + str(command))
    return value


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def validate_bundle(output, model):
    if sha256(output / 'dfn_bg.wasm') != EXPECTED_WASM:
        raise ValueError('Research WASM differs from the pinned loader identity')
    if sha256(output / 'dfn.js') != EXPECTED_GLUE:
        raise ValueError('Generated research glue differs from the pinned identity')
    if sha256(model) != prepare.MODEL_SHA:
        raise ValueError('Model changed after preparation')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, required=True)
    parser.add_argument('--patch-source', type=Path, required=True)
    parser.add_argument('--work', type=Path, required=True)
    parser.add_argument('--bindgen', type=Path, required=True)
    parser.add_argument('--offline', action='store_true')
    args = parser.parse_args()
    work = args.work.resolve()
    if work.exists():
        raise ValueError('Work directory already exists')
    rustc = check_version('rustc', 'rustc 1.97.1')
    cargo = check_version('cargo', 'cargo 1.97.1')
    bindgen = check_version(args.bindgen, 'wasm-bindgen 0.2.118')
    work.mkdir(parents=True, exist_ok=False)
    source, target, output = work / 'source', work / 'target', work / 'bundle'
    subprocess.run([sys.executable, '-m', 'tools.audio.research_dfn_web.prepare',
                    '--source', str(args.source.resolve()), '--patch-source', str(args.patch_source.resolve()),
                    '--output', str(source)], cwd=ROOT, check=True)
    env = dict(os.environ, RUSTFLAGS='-C target-feature=+simd128')
    cmd = ['cargo', 'build', '--release', '--locked', '--no-default-features', '--features', 'wasm',
           '-p', 'deep_filter', '--target', 'wasm32-unknown-unknown', '--target-dir', str(target)]
    if args.offline:
        cmd.append('--offline')
    subprocess.run(cmd, cwd=source, env=env, check=True)
    output.mkdir()
    subprocess.run([str(args.bindgen.resolve()), '--target', 'web', '--out-dir', str(output), '--out-name', 'dfn',
                    str(target / 'wasm32-unknown-unknown/release/df.wasm')], check=True)
    wasm = output / 'dfn_bg.wasm'
    model = source / 'models/DeepFilterNet3_onnx.tar.gz'
    validate_bundle(output, model)
    shutil.copyfile(model, output / 'model.bin')
    report = {'scope': 'research-only', 'upstream': prepare.UPSTREAM, 'patch': prepare.PATCH_COMMIT,
              'patchSha256': prepare.PATCH_SHA, 'lockSha256': prepare.LOCK_SHA,
              'wasmSha256': sha256(wasm), 'glueSha256': sha256(output / 'dfn.js'),
              'modelSha256': sha256(output / 'model.bin'), 'rustc': rustc, 'cargo': cargo, 'bindgen': bindgen}
    (work / 'research-build.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
    print('Pinned research bundle built; it is not approved for release.')


if __name__ == '__main__':
    main()
