"""Developers can test a working tree; CI can only attest its exact clean source."""
import os
from types import SimpleNamespace
import unittest
from unittest.mock import patch
from . import run

SOURCE = 'a' * 40


class SourceTests(unittest.TestCase):
    def test_local_changes_are_allowed_and_marked_dirty(self):
        with patch.dict(os.environ, GITHUB_ACTIONS='false', GITHUB_SHA=SOURCE), \
             patch.object(run, 'output', side_effect=[SOURCE,'v24.18.0']), \
             patch.object(run.subprocess, 'run', return_value=SimpleNamespace(returncode=1)):
            self.assertEqual(run.checked_source(), (SOURCE, True))

    def test_dirty_or_foreign_ci_source_cannot_be_attested(self):
        for revision, code in [(SOURCE,1), ('b'*40,0), (SOURCE,128)]:
            with self.subTest(code=code), patch.dict(os.environ, GITHUB_ACTIONS='true', GITHUB_SHA=SOURCE), \
                 patch.object(run, 'output', side_effect=[revision,'v24.18.0']), \
                 patch.object(run.subprocess, 'run', return_value=SimpleNamespace(returncode=code)), \
                 self.assertRaises(ValueError):
                run.checked_source()
