import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch
from . import prepare
from .prepare import prepare_tree

class WebPrepareTest(unittest.TestCase):
    def make_tree(self, root):
        (root / 'libDF/src').mkdir(parents=True)
        (root / 'Cargo.toml').write_text('members = [\n  "libDF",\n  "pyDF",\n  "pyDF-data",\n  "ladspa",\n  "demo",\n]\n')
        (root / 'libDF/Cargo.toml').write_text(
            '  "dep:hdf5",\nhdf5-static = ["hdf5?/static"]\n'
            'hdf5 = { optional = true, git = "https://github.com/aldanor/hdf5-rust.git", rev = "26046fb" }\n'
            'wasm-bindgen = { version = "0.2.87", optional = true }\n'
            'js-sys = { version = "0.3", optional = true }\n')
        (root / 'libDF/src/wasm.rs').write_text('upstream')

    def test_overlay_removes_unused_dependencies_and_pins_bindings(self):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d); self.make_tree(root)
            prepare_tree(root)
            manifest = (root / 'libDF/Cargo.toml').read_text()
            self.assertNotIn('hdf5', manifest)
            self.assertIn('version = "=0.2.118"', manifest)
            self.assertIn('version = "=0.3.95"', manifest)
            self.assertNotIn('pyDF', (root / 'Cargo.toml').read_text())
            self.assertEqual((root / 'libDF/src/wasm.rs').read_bytes(), (Path(__file__).parent / 'wasm.rs').read_bytes())
            self.assertEqual((root / 'Cargo.lock').read_bytes(), (Path(__file__).parent / 'Cargo.lock').read_bytes())
            with self.assertRaises(ValueError): prepare_tree(root)

    def test_mismatched_patch_rejected_before_output_creation(self):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d)
            output = root / 'new'
            args = ['prepare', '--source', d, '--patch-source', d, '--output', str(output)]
            with patch('sys.argv', args), patch.object(prepare, 'git', side_effect=[(prepare.UPSTREAM + '\n').encode(), b'wrong patch']):
                with self.assertRaises(ValueError): prepare.main()
            self.assertFalse(output.exists())

    def test_drift_rejected_without_editing_manifest(self):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d); self.make_tree(root)
            target = root / 'libDF/Cargo.toml'; target.write_text('unexpected')
            with self.assertRaises(ValueError): prepare_tree(root)
            self.assertEqual(target.read_text(), 'unexpected')

if __name__ == '__main__': unittest.main()
