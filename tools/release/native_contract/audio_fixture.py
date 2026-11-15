"""Synthetic DLL identity with authentic shipped model/notice bytes for archive tests."""
import hashlib
import json
import shutil
from tools.ci.native.process import ROOT
from tools.release.native_artifact.test_audio_component import release_fixture


def populate(native):
    release_fixture(native)
    (native / 'boohta_deepfilter.dll').write_bytes(b'synthetic DLL, never loaded')
    shutil.copyfile(ROOT / 'tools/audio/runtime_assets/deepfilter/model.bin', native / 'boohta_deepfilter_model.tar.gz')
    notices = native / 'licenses/deepfilter'
    notices.mkdir(parents=True)
    sha = lambda path: hashlib.sha256(path.read_bytes()).hexdigest()
    package = notices / 'synthetic-1.0'
    package.mkdir()
    (package / 'LICENSE').write_bytes(b'synthetic test notice')
    (notices / 'index.json').write_text(json.dumps({'packages': 1, 'unresolved': [],
        'entries': [{'package': 'synthetic-1.0', 'notices': {'LICENSE': sha(package / 'LICENSE')}}]}), encoding='utf-8')
    info = {'scope': 'production', 'version': 'DeepFilterNet3', 'panic': 'unwind', 'allocationCounter': False,
            'sourceCommit': '7b14b895fe7fc42cab72b4a4c1e49c982bd6404b',
            'dllSha256': sha(native / 'boohta_deepfilter.dll'), 'noticeIndexSha256': sha(notices / 'index.json')}
    (native / 'deepfilter-engine.json').write_text(json.dumps(info), encoding='utf-8')
