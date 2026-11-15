"""Bind the Windows SBOM to the official distribution installed by CMake."""
import hashlib
import json


def write_release(directory, root):
    lock = json.loads((root / 'tools/audio/release_source/lock.json').read_text(encoding='utf-8'))
    marker = json.loads((directory / 'rnnoise-engine.json').read_text(encoding='utf-8'))
    notice = (directory / 'LICENSE-RNNoise-0.2.txt').read_bytes()
    if marker != lock or hashlib.sha256(notice).hexdigest() != lock['files']['COPYING']:
        raise ValueError('Windows RNNoise release identity or notice differs from the pinned distribution')
    model = lock['files']['src/rnnoise_data.c']
    component = {'type': 'library', 'name': 'RNNoise', 'version': lock['version'],
                 'licenses': [{'license': {'id': lock['license']}}],
                 'externalReferences': [{'type': 'distribution', 'url': lock['url']}],
                 'properties': [{'name': 'rnnoise:model-sha256', 'value': model},
                                {'name': 'rnnoise:source-archive-sha256', 'value': lock['archiveSha256']}]}
    sbom = {'bomFormat': 'CycloneDX', 'specVersion': '1.5', 'version': 1, 'components': [component]}
    (directory / 'rnnoise-component.cdx.json').write_text(json.dumps(sbom, indent=2) + '\n', encoding='utf-8')
    (directory / 'LICENSE-RNNoise.txt').write_bytes(notice)
    return {'source_commit': lock['sourceCommit'], 'model_sha256': model,
            'model_id': lock['modelId'], 'version': lock['version'],
            'sbom': 'rnnoise-component.cdx.json', 'license': 'LICENSE-RNNoise.txt'}
