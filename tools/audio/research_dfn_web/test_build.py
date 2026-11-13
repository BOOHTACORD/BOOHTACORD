import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch
from . import build

class BuildValidationTest(unittest.TestCase):
    def test_existing_work_directory_never_overwritten(self):
        with tempfile.TemporaryDirectory() as d:
            marker = Path(d) / 'keep'; marker.write_text('original')
            args = ['build', '--source', d, '--patch-source', d, '--work', d, '--bindgen', 'unused']
            with patch('sys.argv', args), patch.object(build.subprocess, 'check_output') as invoke:
                with self.assertRaises(ValueError): build.main()
                invoke.assert_not_called()
            self.assertEqual(marker.read_text(), 'original')

    def test_tampered_generated_glue_is_rejected_before_staging(self):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d); (root / 'dfn_bg.wasm').write_bytes(b'wasm')
            (root / 'dfn.js').write_bytes(b'tampered')
            model = root / 'model-source'; model.write_bytes(b'model')
            with patch.object(build, 'EXPECTED_WASM', build.sha256(root / 'dfn_bg.wasm')), \
                 patch.object(build, 'EXPECTED_GLUE', '0' * 64), \
                 patch.object(build.prepare, 'MODEL_SHA', build.sha256(model)):
                with self.assertRaises(ValueError): build.validate_bundle(root, model)
            self.assertFalse((root / 'model.bin').exists())

    def test_wrong_bindgen_rejected_before_creating_work(self):
        with tempfile.TemporaryDirectory() as d:
            work = Path(d) / 'new'
            args = ['build', '--source', d, '--patch-source', d, '--work', str(work), '--bindgen', 'unused']
            versions = [b'rustc 1.97.1 (test)', b'cargo 1.97.1 (test)', b'wasm-bindgen 0.2.117']
            with patch('sys.argv', args), patch.object(build.subprocess, 'check_output', side_effect=versions):
                with self.assertRaises(ValueError): build.main()
            self.assertFalse(work.exists())

if __name__ == '__main__': unittest.main()
