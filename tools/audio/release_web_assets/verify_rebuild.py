"""Compare shipped Web runtimes with independently rebuilt, pinned sources."""
import argparse
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]


def verify(rnnoise, deepfilter):
    identity = json.loads((ROOT / 'tools/audio/release_web_assets/identity.json').read_text(encoding='utf-8'))
    for prefix, directory, names in [('rnnoise', rnnoise, ['rnnoise.wasm']),
                                     ('deepfilter', deepfilter, ['dfn_bg.wasm', 'dfn.js', 'model.bin'])]:
        for name in names:
            actual = hashlib.sha256((directory / name).read_bytes()).hexdigest()
            if actual != identity['files'][prefix + '/' + name]:
                raise ValueError('Source rebuild differs from shipped runtime: ' + prefix + '/' + name)
    print('PASS: independently rebuilt RNNoise 0.2 and DeepFilterNet3 match the ordinary Web delivery')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--rnnoise', type=Path, required=True)
    parser.add_argument('--deepfilter', type=Path, required=True)
    args = parser.parse_args()
    verify(args.rnnoise, args.deepfilter)
