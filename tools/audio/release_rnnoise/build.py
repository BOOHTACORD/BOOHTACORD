"""Compile the complete official RNNoise 0.2 distribution to production WASM."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess

from tools.audio.release_source.verify import prepare, load
from tools.audio.research_v02.build_wasm import SOURCES

ROOT = Path(__file__).resolve().parents[3]
BRIDGE = ROOT / 'tools/audio/research_v02'


def build(output, compiler):
    output = output.resolve()
    if output.exists():
        raise ValueError('Production output already exists')
    lock = load()
    source = prepare(output.parent / 'rnnoise-source')
    version = subprocess.check_output([str(compiler), '--version'], text=True)
    if 'Emscripten gcc/clang-like replacement + linker emulating GNU ld) 4.0.20' not in version:
        raise ValueError('Production RNNoise requires Emscripten 4.0.20')
    output.mkdir(parents=True, exist_ok=False)
    wasm = output / 'rnnoise.wasm'
    command = [str(compiler), '-O3', '-DNDEBUG', '-DRNNOISE_BUILD',
               '-I' + str(source / 'include'), '-I' + str(source / 'src'), '-I' + str(BRIDGE),
               *[str(source / 'src' / name) for name in SOURCES], str(BRIDGE / 'bridge.c'),
               '-lm', '--no-entry', '-sSTANDALONE_WASM=1', '-sALLOW_MEMORY_GROWTH=0',
               '-sINITIAL_MEMORY=33554432', '-sSTACK_SIZE=1048576', '-sFILESYSTEM=0',
               '-sMALLOC=emmalloc', '-sASSERTIONS=0',
               '-sEXPORTED_FUNCTIONS=["_ns_init","_ns_reset","_ns_input","_ns_output","_ns_process"]',
               '-o', str(wasm)]
    subprocess.run(command, check=True, env={**os.environ, 'SOURCE_DATE_EPOCH': '1514764800'})
    sha = lambda path: hashlib.sha256(path.read_bytes()).hexdigest()
    manifest = {'version': 'v0.2-904a876', 'modelId': lock['modelId'],
                'sourceCommit': lock['sourceCommit'], 'sourceArchiveSha256': lock['archiveSha256'],
                'modelSha256': lock['files']['src/rnnoise_data.c'],
                'wasmSha256': sha(wasm), 'wasmFile': 'rnnoise.wasm', 'sampleRate': 48000,
                'frameSize': 480, 'pcmScale': 32768, 'threads': 1, 'simd': False,
                'buildKind': 'production', 'license': lock['license'],
                'noticeFile': 'LICENSE-RNNoise-0.2.txt', 'noticeSha256': lock['files']['COPYING'],
                'emscriptenVersion': '4.0.20'}
    shutil.copyfile(source / 'COPYING', output / manifest['noticeFile'])
    (output / 'rnnoise-manifest.json').write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')
    print(json.dumps(manifest))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--emcc', type=Path, required=True)
    args = parser.parse_args()
    build(args.output, args.emcc)


if __name__ == '__main__':
    main()
