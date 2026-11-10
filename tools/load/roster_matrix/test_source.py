import tempfile
import unittest
from pathlib import Path

from tools.load.roster_matrix.source import source_identity


class SourceIdentityTest(unittest.TestCase):
    def test_dirty_source_requires_explicit_smoke_and_is_not_immutable(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / '.git').write_text('fixture')
            def git(*args):
                return 'M changed' if 'status' in args else 'a' * 40
            with self.assertRaises(ValueError):
                source_identity(root, False, git)
            self.assertEqual(source_identity(root, True, git), ('a' * 40, False))

    def test_clean_source_requires_valid_revision_and_checkout_root(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / '.git').write_text('fixture')
            def git(*args):
                return '' if 'status' in args else 'b' * 40
            self.assertEqual(source_identity(root, False, git), ('b' * 40, True))
            with self.assertRaises(ValueError):
                source_identity(root, False, lambda *_: 'bad')
            with self.assertRaises(ValueError):
                source_identity(root / 'nested', False, git)
