import subprocess
import tempfile
import unittest
from pathlib import Path

from .source_identity import source_identity, source_stability


class SourceIdentityTest(unittest.TestCase):
    def test_staged_and_untracked_changes_affect_identity(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            def git(*args):
                return subprocess.check_output(['git', '-C', str(root), *args], stderr=subprocess.DEVNULL)
            git('init')
            git('config', 'user.email', 'qa@example.invalid')
            git('config', 'user.name', 'QA')
            (root / 'tracked').write_text('one')
            git('add', 'tracked')
            git('commit', '-m', 'baseline')
            clean = source_identity(root)
            (root / 'tracked').write_text('two')
            git('add', 'tracked')
            staged = source_identity(root)
            self.assertNotEqual(clean, staged)
            (root / 'new').write_text('first')
            untracked = source_identity(root)
            self.assertNotEqual(staged, untracked)
            (root / 'new').write_text('second')
            self.assertNotEqual(untracked, source_identity(root))

    def test_source_change_during_run_blocks_evidence(self):
        self.assertEqual(source_stability('before', 'before')['status'], 'PASS')
        self.assertEqual(source_stability('before', 'after')['status'], 'BLOCKED')


if __name__ == '__main__':
    unittest.main()
