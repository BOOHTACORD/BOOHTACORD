import hashlib
import json
import os
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from .verify import checked_file, checked_source
from .build_wasm import build
from .build_native import build as build_native
from .verify import RESEARCH_ROOT


class ResearchSourceTests(unittest.TestCase):
    def test_rejects_changed_and_missing_model_weights(self):
        descriptor, name = tempfile.mkstemp()
        os.close(descriptor)
        path = Path(name)
        try:
            path.write_bytes(b'known weights')
            digest = hashlib.sha256(b'known weights').hexdigest()
            checked_file(path, digest)
            path.write_bytes(b'other weights')
            with self.assertRaisesRegex(ValueError, 'checksum'):
                checked_file(path, digest)
        finally:
            path.unlink()
        with self.assertRaises(FileNotFoundError):
            checked_file(path, digest)

    def test_rejects_outputs_outside_ignored_research_directory(self):
        with self.assertRaisesRegex(ValueError, 'research output'):
            build(Path('missing'), Path('clients/web/public/audio/rnnoise').resolve())
        with self.assertRaisesRegex(ValueError, 'research output'):
            build_native(Path('missing'), Path('clients/web/public/audio/rnnoise').resolve(), 'cmake')

    def test_rejects_a_different_upstream_commit_before_building(self):
        with patch('tools.audio.research_v02.verify.subprocess.check_output', return_value='other\n'):
            with self.assertRaisesRegex(ValueError, 'commit mismatch'):
                checked_source(Path('unused'), {'sourceCommit': 'expected'})

    def test_native_build_passes_normalized_source_path_to_cmake(self):
        source = Path('test-source').resolve()
        with patch('tools.audio.research_v02.build_native.checked_source'), \
             patch('tools.audio.research_v02.build_native.subprocess.run') as run, \
             patch.object(Path, 'mkdir'):
            build_native(source, RESEARCH_ROOT / 'unit-only', 'cmake')
        self.assertIn('-DRNNOISE_SOURCE=' + source.as_posix(), run.call_args_list[0].args[0])

    def test_web_model_identity_matches_the_research_lock(self):
        root = Path(__file__).resolve().parents[3]
        lock = json.loads((Path(__file__).with_name('lock.json')).read_text(encoding='utf-8'))
        web = (root / 'clients/web/src/voice/noise_suppression/rnnoise_model.ts').read_text(encoding='utf-8')
        for key in ('version', 'sourceCommit', 'sourceArchiveSha256', 'modelSha256', 'modelId'):
            with self.subTest(key=key):
                self.assertIn("'" + lock[key] + "'", web)
