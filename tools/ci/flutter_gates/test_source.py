"""Generated reports must never attest a dirty or foreign checkout."""
import unittest
from unittest.mock import patch
from . import source


class SourceTests(unittest.TestCase):
    def test_clean_exact_current_source_and_public_run_identity(self):
        env = {'GITHUB_ACTIONS': 'true', 'GITHUB_REPOSITORY': 'BOOHTACORD/BOOHTACORD',
               'GITHUB_SHA': 'a' * 40, 'GITHUB_RUN_ID': '123', 'GITHUB_RUN_ATTEMPT': '1',
               'FLUTTER_EVIDENCE_NAMESPACE': 'flutter'}
        self.assertEqual(('a' * 40, '123', '1', 'flutter'), source.context(env))
        with patch.object(source, 'output', side_effect=['a' * 40, '']):
            source.verify('a' * 40)
        for values in (['b' * 40, ''], ['a' * 40, ' M tracked-input']):
            with patch.object(source, 'output', side_effect=values), self.assertRaises(ValueError):
                source.verify('a' * 40)

    def test_missing_source_local_run_and_invalid_attempt_are_not_ci_evidence(self):
        env = {'GITHUB_ACTIONS': 'true', 'GITHUB_REPOSITORY': 'BOOHTACORD/BOOHTACORD',
               'GITHUB_SHA': 'a' * 40, 'GITHUB_RUN_ID': '123', 'GITHUB_RUN_ATTEMPT': '1',
               'FLUTTER_EVIDENCE_NAMESPACE': 'flutter'}
        for key, bad in [('GITHUB_ACTIONS', 'false'), ('GITHUB_REPOSITORY', 'former-owner/BOOHTACORD'),
                         ('GITHUB_REPOSITORY', 'fork/repo'),
                         ('GITHUB_SHA', ''), ('GITHUB_RUN_ID', 'local'), ('GITHUB_RUN_ATTEMPT', '0'),
                         ('FLUTTER_EVIDENCE_NAMESPACE', '../another'), ('FLUTTER_EVIDENCE_NAMESPACE', '')]:
            with self.subTest(key=key), self.assertRaises(ValueError): source.context(dict(env, **{key: bad}))
