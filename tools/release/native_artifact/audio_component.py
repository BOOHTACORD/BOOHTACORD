"""Component-level SBOM for the native linked RNNoise core and fixed model."""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]


def write_audio_component(directory, *, root=ROOT, platform=None):
    if platform == 'windows':
        from .audio_release import write_release
        return write_release(directory, root)
    lock = json.loads((root / 'tools/audio/rnnoise_build_lock.json').read_text())
    upstream = root / 'clients/flutter/packages/flutter_webrtc/common/rnnoise/upstream'
    model_hash = hashlib.sha256((upstream / 'src/rnn_data.c').read_bytes()).hexdigest()
    if model_hash != lock['modelSha256']:
        raise ValueError('Native RNNoise model differs from locked source')
    sbom = {'bomFormat': 'CycloneDX', 'specVersion': '1.5', 'version': 1, 'components': [{
        'type': 'library', 'name': 'RNNoise', 'version': lock['version'],
        'licenses': [{'license': {'id': 'BSD-3-Clause'}}],
        'externalReferences': [{'type': 'vcs', 'url': lock['sourceUrl'] + '/tree/' + lock['sourceCommit']}],
        'properties': [{'name': 'rnnoise:model-sha256', 'value': model_hash},
                       {'name': 'rnnoise:source-archive-sha256', 'value': lock['sourceArchiveSha256']}]}]}
    (directory / 'rnnoise-component.cdx.json').write_text(json.dumps(sbom, indent=2) + '\n', encoding='utf-8')
    (directory / 'LICENSE-RNNoise.txt').write_text((upstream / 'COPYING').read_text(), encoding='utf-8')
    result = {'source_commit': lock['sourceCommit'], 'model_sha256': model_hash,
            'sbom': 'rnnoise-component.cdx.json', 'license': 'LICENSE-RNNoise.txt'}
    return result
