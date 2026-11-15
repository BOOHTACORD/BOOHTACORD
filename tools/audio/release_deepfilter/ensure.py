"""Prepare or verify production DeepFilter assets for the normal native build."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
from .native import build, ROOT
from .signing import prepare
from tools.audio.research_dfn_native.prepare import COMMIT, MODEL_SHA


def validate(output):
    info = json.loads((output / 'engine.json').read_text(encoding='utf-8'))
    if (info['sourceCommit'] != COMMIT or info['modelSha256'] != MODEL_SHA or
            info['scope'] != 'production' or info['allocationCounter'] or info['panic'] != 'unwind'):
        raise ValueError('Unqualified DeepFilter production artifact')
    for file, expected in [('boohta_deepfilter.dll', info['dllSha256']),
                           ('boohta_deepfilter_model.tar.gz', MODEL_SHA),
                           ('DeepFilterNet-LICENSE-Rust-1.97.1.html', '0a65bb747c49c7bb816cbc7188319bd6e4e8d08091c1190b8a3c0971c47968ed'),
                           ('notices/index.json', info['noticeIndexSha256'])]:
        if hashlib.sha256((output / file).read_bytes()).hexdigest() != expected:
            raise ValueError('Production DeepFilter checksum mismatch: ' + file)
    notices = json.loads((output / 'notices/index.json').read_text(encoding='utf-8'))
    if notices['unresolved'] or not notices['packages']:
        raise ValueError('Production DeepFilter notices incomplete')
    for package in notices['entries']:
        for file, expected in package['notices'].items():
            text = output / 'notices' / package['package'] / file
            if hashlib.sha256(text.read_bytes()).hexdigest() != expected:
                raise ValueError('Delivered dependency notice changed')
    return output


def ensure():
    cache = Path(os.environ.get('BOOHTA_ENGINE_CACHE_ROOT', ROOT / '.out/audio-engines')).resolve()
    output = cache / 'windows-deepfilter-v3'
    if output.exists():
        return validate(prepare(validate(output)))
    cache.mkdir(parents=True, exist_ok=True)
    source = cache / 'DeepFilterNet'
    if not (source / '.git').exists():
        subprocess.run(['git', 'clone', '--filter=blob:none', '--no-checkout',
                        'https://github.com/Rikorose/DeepFilterNet.git', str(source)], check=True)
    found = subprocess.check_output(['git', '-C', str(source), 'rev-parse', COMMIT + '^{commit}'], text=True)
    if found.strip() != COMMIT:
        raise ValueError('Production DeepFilter source commit mismatch')
    build(source, output, cache / 'native-target')
    return validate(prepare(validate(output)))


if __name__ == '__main__':
    # The build prints diagnostics; the final line alone is the verified path.
    print(ensure().as_posix())
