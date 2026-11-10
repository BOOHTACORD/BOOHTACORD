import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from tools.product_map.impact.changes import changed_paths


class ChangedPathsTests(unittest.TestCase):
    def test_real_git_rename_reports_both_names(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            def git(*args):
                return subprocess.run(['git', *args], cwd=root, check=True,
                                      stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            git('init')
            (root / 'old.txt').write_text('contents', encoding='utf-8')
            git('add', 'old.txt')
            git('-c', 'user.name=Test', '-c', 'user.email=test@example.invalid',
                '-c', 'commit.gpgsign=false', 'commit', '-m', 'base')
            base = git('rev-parse', 'HEAD').stdout.decode().strip()
            git('mv', 'old.txt', 'new.txt')
            git('-c', 'user.name=Test', '-c', 'user.email=test@example.invalid',
                '-c', 'commit.gpgsign=false', 'commit', '-m', 'rename')
            self.assertEqual(set(changed_paths(root, base)), {'old.txt', 'new.txt'})

    @patch('tools.product_map.impact.changes.subprocess.run')
    def test_uses_exact_sha_and_includes_old_and_new_rename_paths(self, run):
        run.return_value = subprocess.CompletedProcess([], 0, b'old/path\0new/path\0')
        result = changed_paths('root', 'a' * 40)
        self.assertEqual(result, ['old/path', 'new/path'])
        args = run.call_args.args[0]
        self.assertIn('--no-renames', args)
        self.assertIn('a' * 40 + '...HEAD', args)
        self.assertIn('-z', args)

    def test_rejects_options_and_non_sha_base(self):
        for base in ('--help', 'master', 'a' * 39, 'g' * 40):
            with self.subTest(base=base), self.assertRaises(ValueError):
                changed_paths('root', base)

    @patch('tools.product_map.impact.changes.subprocess.run')
    def test_git_failure_is_not_empty_impact(self, run):
        run.side_effect = subprocess.CalledProcessError(128, ['git'])
        with self.assertRaises(subprocess.CalledProcessError):
            changed_paths('root', 'a' * 40)
