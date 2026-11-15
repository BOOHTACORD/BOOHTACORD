import unittest
import subprocess
import tempfile
from pathlib import Path
from unittest.mock import patch

from tools.ci.preflight.client_registry import check, review_changes


class ClientRegistryTest(unittest.TestCase):
    def setUp(self):
        self.old = {'chat': {'paths': ['clients/web/src/chat/**'],
                             'parity_review': {'issue': 12}}}

    def test_changed_scenario_requires_new_platform_decision(self):
        paths = ['clients/web/src/chat/send.ts']
        with self.assertRaisesRegex(ValueError, 'chat'):
            review_changes(paths, self.old, self.old)
        updated = {'chat': {'paths': ['clients/web/src/chat/**'],
                            'parity_review': {'issue': 13}}}
        review_changes(paths, self.old, updated)

    def test_unrelated_changes_do_not_require_registry_update(self):
        review_changes(['docs/example.md'], self.old, self.old)

    def test_missing_feature_is_left_for_explicit_semantic_review(self):
        unknown = review_changes(['clients/web/src/other.ts'], self.old, self.old)
        self.assertEqual(unknown, ['clients/web/src/other.ts'])

    def test_unavailable_base_registry_is_blocked(self):
        changes = {'paths': ['clients/web/src/chat/send.ts'], 'merge_base': 'abc', 'staged': []}
        with patch('tools.ci.preflight.client_registry.subprocess.check_output',
                   side_effect=subprocess.CalledProcessError(1, 'git')):
            self.assertEqual(check('.', changes)['status'], 'BLOCKED')

    def test_incomplete_registry_fails_native_parity_validation(self):
        with tempfile.TemporaryDirectory() as directory:
            registry = Path(directory) / 'tools/qa/local_features/features.json'
            registry.parent.mkdir(parents=True)
            registry.write_text('{"chat":{"paths":[],"parity_review":{"issue":12}}}')
            changes = {'paths': ['tools/qa/local_features/features.json'], 'merge_base': 'abc', 'staged': []}
            with patch('tools.ci.preflight.client_registry.subprocess.check_output', return_value=b'{}'):
                self.assertEqual(check(directory, changes)['status'], 'FAIL')


if __name__ == '__main__':
    unittest.main()
