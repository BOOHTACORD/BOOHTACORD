import hashlib
import os
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from .verify import checked_file, checked_source
from .build_wasm import build


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

    def test_rejects_a_different_upstream_commit_before_building(self):
        with patch('tools.audio.research_v02.verify.subprocess.check_output', return_value='other\n'):
            with self.assertRaisesRegex(ValueError, 'commit mismatch'):
                checked_source(Path('unused'), {'sourceCommit': 'expected'})
