"""Build the pinned, noninstrumented DeepFilter engine for ordinary Windows builds."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

from tools.audio.research_dfn_native.prepare import COMMIT, MODEL_SHA
from tools.audio.release_notices.collect import collect
from .compiler import select
from .notices import stage

ROOT = Path(__file__).resolve().parents[3]


def build(source, output, target):
    if output.exists():
        raise ValueError('Production output already exists')
    compiler_env, version = select()
    work = output.parent / (output.name + '-source')
    subprocess.run([sys.executable, '-m', 'tools.audio.research_dfn_native.prepare',
                    '--source', str(source), '--output', str(work),
                    '--without-allocation-counter'], cwd=ROOT, check=True, stdout=subprocess.DEVNULL)
    cargo_home = Path(os.environ.get('CARGO_HOME', Path.home() / '.cargo')).resolve()
    flags = ['-Ctarget-feature=+crt-static', '-Clink-arg=/Brepro', '-Cpanic=unwind',
             f'--remap-path-prefix={work.resolve()}=/source',
             f'--remap-path-prefix={cargo_home}=/cargo']
    env = {**compiler_env, 'CARGO_ENCODED_RUSTFLAGS': '\x1f'.join(flags)}
    env.pop('RUSTFLAGS', None)
    args = ['cargo', 'build', '--release', '--locked', '--no-default-features',
            '--features', 'capi', '-p', 'deep_filter', '--target-dir', str(target)]
    subprocess.run(args, cwd=work, env=env, check=True)
    metadata = subprocess.check_output(['cargo', 'metadata', '--format-version', '1',
                  '--locked', '--no-default-features', '--features', 'capi',
                  '--filter-platform', 'x86_64-pc-windows-msvc'], cwd=work, env=env)
    output.mkdir(parents=True, exist_ok=False)
    dll, model = output / 'boohta_deepfilter.dll', output / 'boohta_deepfilter_model.tar.gz'
    shutil.copyfile(target / 'release/df.dll', dll)
    shutil.copyfile(work / 'models/DeepFilterNet3_onnx.tar.gz', model)
    sha = lambda path: hashlib.sha256(path.read_bytes()).hexdigest()
    if sha(model) != MODEL_SHA:
        raise ValueError('Production model hash mismatch')
    subprocess.run([sys.executable, '-m', 'tools.audio.research_dfn_native.fingerprint',
                    '--dll', str(dll), '--dll-sha256', sha(dll), '--model', str(model)],
                   cwd=ROOT, check=True)
    stage(work, output)
    (output / 'cargo-metadata.json').write_bytes(metadata)
    collect(json.loads(metadata), output / 'notices')
    manifest = dict(scope='production', version='DeepFilterNet3', backend='libDF 0.5.7-pre',
                    sourceCommit=COMMIT, modelSha256=MODEL_SHA, dllSha256=sha(dll),
                    rustc=version.strip(), panic='unwind', allocationCounter=False,
                    noticeIndexSha256=sha(output / 'notices/index.json'))
    (output / 'engine.json').write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')
    print(json.dumps(manifest))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--target', type=Path, required=True)
    args = parser.parse_args()
    build(args.source.resolve(), args.output.resolve(), args.target.resolve())
