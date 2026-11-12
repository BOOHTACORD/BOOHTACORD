"""Build a version-pinned v0.2 research probe; never a release artifact."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess

from .verify import checked_source, check_output

HERE = Path(__file__).resolve().parent
SOURCES = ('denoise.c', 'rnn.c', 'pitch.c', 'kiss_fft.c', 'celt_lpc.c', 'nnet.c',
           'nnet_default.c', 'parse_lpcnet_weights.c', 'rnnoise_data.c', 'rnnoise_tables.c')


def build(source, output):
    check_output(output)
    lock = json.loads((HERE / 'lock.json').read_text(encoding='utf-8'))
    checked_source(source, lock)
    compiler = os.environ.get('EMCC') or shutil.which('emcc')
    if not compiler:
        raise ValueError('Emscripten compiler missing')
    version = subprocess.check_output([compiler, '--version'], text=True)
    if ('Emscripten gcc/clang-like replacement + linker emulating GNU ld) '
            + lock['emscriptenVersion']) not in version:
        raise ValueError('incorrect Emscripten version')
    output.mkdir(parents=True, exist_ok=False)
    wasm = output / 'rnnoise.wasm'
    command = [compiler, '-O3', '-DNDEBUG', '-DRNNOISE_BUILD',
               '-I' + str(source / 'include'), '-I' + str(source / 'src'), '-I' + str(HERE),
               *[str(source / 'src' / name) for name in SOURCES], str(HERE / 'bridge.c'),
               '-lm', '--no-entry', '-sSTANDALONE_WASM=1', '-sALLOW_MEMORY_GROWTH=0',
               '-sINITIAL_MEMORY=33554432', '-sSTACK_SIZE=1048576', '-sFILESYSTEM=0',
               '-sMALLOC=emmalloc', '-sASSERTIONS=0',
               '-sEXPORTED_FUNCTIONS=["_ns_init","_ns_reset","_ns_input","_ns_output","_ns_process"]',
               '-o', str(wasm)]
    subprocess.run(command, check=True, env={**os.environ, 'SOURCE_DATE_EPOCH': '1514764800'})
    digest = hashlib.sha256(wasm.read_bytes()).hexdigest()
    manifest = {**lock, 'wasmSha256': digest, 'wasmFile': 'rnnoise.wasm', 'sampleRate': 48000,
                'frameSize': 480, 'pcmScale': 32768, 'threads': 1, 'simd': False}
    (output / 'rnnoise-manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    print(json.dumps({'status': 'research-only', 'wasmSha256': digest}))


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--source', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    build(args.source.resolve(), args.output.resolve())
