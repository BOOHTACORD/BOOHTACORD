import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from tools.ci.preflight.inventory import inventory
from tools.ci.preflight.run import report
from tools.ci.preflight.review import decision
from tools.ci.select_changes.selection import classify


class InventoryTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.git('init', '-q')
        self.git('config', 'user.email', 'test@example.invalid')
        self.git('config', 'user.name', 'test')
        (self.root / 'old.txt').write_text('old\n')
        self.git('add', 'old.txt')
        self.git('commit', '-qm', 'base')

    def git(self, *args):
        return subprocess.run(['git', *args], cwd=self.root, check=True,
                              capture_output=True).stdout

    def test_includes_rename_deletion_staged_unstaged_and_untracked(self):
        self.git('mv', 'old.txt', 'new.txt')
        (self.root / 'new.txt').write_text('modified\n')
        (self.root / 'extra.txt').write_text('extra\n')
        result = inventory(self.root, 'HEAD')
        self.assertEqual(set(result['staged']), {'old.txt', 'new.txt'})
        self.assertEqual(result['unstaged'], ['new.txt'])
        self.assertEqual(result['untracked'], ['extra.txt'])
        self.assertEqual(set(result['paths']), {'old.txt', 'new.txt', 'extra.txt'})

    def test_bad_base_fails_closed(self):
        with self.assertRaises(subprocess.CalledProcessError):
            inventory(self.root, 'nonexistent-ref')

    def test_untracked_whitespace_blocks_fast_check(self):
        (self.root / 'new.txt').write_text('trailing space \n')
        result = report(self.root, 'HEAD')
        self.assertEqual(result['diff_check'], 'FAIL')
        self.assertEqual(result['decision'], 'COMMIT_BLOCKED')

    def test_unknown_path_is_uncertain_and_cannot_pass(self):
        (self.root / 'new.txt').write_text('clean\n')
        result = report(self.root, 'HEAD')
        self.assertTrue(result['selection']['uncertain'])
        self.assertIn('new.txt', result['unknown_paths'])
        self.assertTrue(result['actual_acceptance']['uncertain'])
        self.assertTrue(result['actual_acceptance']['profiles'])
        self.assertEqual(result['decision'], 'COMMIT_BLOCKED')

    def test_staged_dependency_change_is_seen_even_if_worktree_is_reverted(self):
        directory = self.root / 'clients/web'
        directory.mkdir(parents=True)
        manifest = directory / 'package.json'
        manifest.write_text('{"dependencies":{"a":"1"}}')
        self.git('add', 'clients/web/package.json')
        self.git('commit', '-qm', 'manifest')
        manifest.write_text('{"dependencies":{"a":"2"}}')
        self.git('add', 'clients/web/package.json')
        manifest.write_text('{"dependencies":{"a":"1"}}')
        result = report(self.root, 'HEAD')
        self.assertIn('without a lockfile diff', result['dependency_review'])

    def test_snapshot_changes_with_untracked_content(self):
        path = self.root / 'new.txt'
        path.write_text('first\n')
        first = report(self.root, 'HEAD')['fingerprint']
        path.write_text('second\n')
        self.assertNotEqual(first, report(self.root, 'HEAD')['fingerprint'])

    def test_synthetic_diff_fix_and_explicit_review(self):
        path = self.root / 'docs/example.md'
        path.parent.mkdir()
        path.write_text('bad \n')
        generated = {'fixture': {'status': 'PASS'}}
        with patch('tools.ci.preflight.run.generated_checks', return_value=generated):
            bad = report(self.root, 'HEAD')
            self.assertEqual(bad['diff_check'], 'FAIL')
            path.write_text('clean\n')
            fixed = report(self.root, 'HEAD')
        checks = {name: {'status': 'N/A', 'reason': 'not applicable'} for name in
                  ('Traceability', 'Evidence', 'Generated', 'Dependencies', 'Client checks')}
        checks.update({name: {'status': 'PASS', 'reason': 'synthetic fixture', 'command': 'fixture'}
                       for name in ('Contracts', 'gate:contracts')})
        review = {'fingerprint': fixed['fingerprint'], 'checks': checks}
        self.assertEqual(decision(bad, review), 'COMMIT_BLOCKED')
        self.assertEqual(decision(fixed, review), 'COMMIT_ALLOWED')

    def test_existing_selector_retains_unknown_and_mixed_semantics(self):
        self.assertEqual(classify(['docs/a.md'])['gates'], ['contracts'])
        self.assertTrue(classify(['docs/a.md', 'unowned/file'])['uncertain'])
        self.assertIn('windows', classify(['backend/a.go', 'clients/flutter/a.dart'])['gates'])


if __name__ == '__main__':
    unittest.main()
