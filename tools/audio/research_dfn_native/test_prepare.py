import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from . import prepare
from .prepare import prepare_tree


class PrepareTreeTest(unittest.TestCase):
    @staticmethod
    def create_upstream(root):
        (root / 'libDF/src').mkdir(parents=True)
        (root / 'Cargo.toml').write_text('members = [\n  "libDF",\n  "pyDF",\n  "pyDF-data",\n  "ladspa",\n  "demo",\n]\n')
        (root / 'libDF/Cargo.toml').write_text(
            '  "dep:hdf5",\nhdf5-static = ["hdf5?/static"]\n'
            'hdf5 = { optional = true, git = "https://github.com/aldanor/hdf5-rust.git", rev = "26046fb" }\n')
        (root / 'libDF/src/lib.rs').write_text('#![allow(dead_code)]\n\npub mod tract;\n')

    def test_exact_overlay_and_repeat_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self.create_upstream(root)
            prepare_tree(root)
            self.assertEqual((root / 'Cargo.lock').read_bytes(), (Path(__file__).parent / 'Cargo.lock').read_bytes())
            self.assertEqual((root / 'libDF/src/research_safe.rs').read_text(), (Path(__file__).parent / 'safe.rs').read_text())
            self.assertEqual((root / 'libDF/src/research_alloc.rs').read_text(), (Path(__file__).parent / 'alloc.rs').read_text())
            self.assertNotIn('pyDF', (root / 'Cargo.toml').read_text())
            self.assertNotIn('hdf5', (root / 'libDF/Cargo.toml').read_text())
            self.assertIn('mod research_safe;', (root / 'libDF/src/lib.rs').read_text())
            with self.assertRaises(ValueError):
                prepare_tree(root)

    def test_noninstrumented_tree_does_not_install_global_allocator(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self.create_upstream(root)
            prepare_tree(root, instrumented=False)
            self.assertFalse((root / 'libDF/src/research_alloc.rs').exists())
            self.assertNotIn('research_alloc', (root / 'libDF/src/lib.rs').read_text())
            self.assertIn('mod research_safe;', (root / 'libDF/src/lib.rs').read_text())

    def test_drift_is_rejected_without_substitution(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'libDF/src').mkdir(parents=True)
            (root / 'Cargo.toml').write_text('members = ["unexpected"]\n')
            (root / 'libDF/Cargo.toml').write_text('')
            (root / 'libDF/src/lib.rs').write_text('')
            with self.assertRaises(ValueError):
                prepare_tree(root)
            self.assertEqual((root / 'Cargo.toml').read_text(), 'members = ["unexpected"]\n')

    def test_unknown_commit_does_not_create_output(self):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / 'new'
            arguments = ['prepare', '--source', directory, '--output', str(output)]
            with patch('sys.argv', arguments), patch.object(prepare.subprocess, 'check_output', return_value='other\n'):
                with self.assertRaises(ValueError):
                    prepare.main()
            self.assertFalse(output.exists())


if __name__ == '__main__':
    unittest.main()
