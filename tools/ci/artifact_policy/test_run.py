"""The actual packaging entrypoint keeps failed steps and stale data fail-closed."""
import json
import os
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch
from . import run, publication
from .test_captures import identity
from . import test_publication as fixtures


class CaptureRunTests(unittest.TestCase):
    def test_begin_and_finish_use_verified_hosted_identity_and_current_job_status(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp).resolve(); current = identity()
            with patch.object(run, 'ROOT', root), patch.object(run.publication_context, 'checked', return_value=current) as checked:
                self.assertEqual(0, run.main(['begin', 'web', 'browser-shell']))
                with patch.dict(os.environ, {'CAPTURE_UPSTREAM_STATUS': 'failure'}, clear=True):
                    self.assertEqual(0, run.main(['finish', 'web', 'browser-shell']))
                self.assertEqual(3, checked.call_count)
            package = publication.destination(root, current)
            self.assertTrue((package / 'artifact-manifest.json').is_file())

    def test_foreign_context_never_publishes_and_errors_do_not_echo_values(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp).resolve()
            with patch.object(run, 'ROOT', root), patch.object(run.publication_context, 'checked', side_effect=ValueError('private-canary')), \
                 patch('builtins.print') as printed:
                self.assertEqual(1, run.main(['begin', 'web', 'browser-shell']))
                self.assertNotIn('private-canary', str(printed.call_args_list))
            self.assertFalse((root / '.out').exists())

    def test_git_process_failure_is_reported_without_command_output(self):
        import subprocess
        with patch.object(run.publication_context, 'checked', side_effect=subprocess.CalledProcessError(
                1, ['git', 'rev-parse', 'HEAD'], output='private-canary')), patch('builtins.print') as printed:
            self.assertEqual(1, run.main(['begin', 'web', 'browser-shell']))
            self.assertNotIn('private-canary', str(printed.call_args_list))

    def test_source_change_after_packaging_removes_only_the_new_upload_directory(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp).resolve(); current, _, _ = fixtures.CapturePublicationTests().fixture(root)
            with patch.object(run, 'ROOT', root), patch.object(run.publication_context, 'checked', side_effect=[current, ValueError('changed')]), \
                 patch.dict(os.environ, {'CAPTURE_UPSTREAM_STATUS': 'success'}, clear=True):
                self.assertEqual(1, run.main(['finish', 'web', 'browser-shell']))
            self.assertFalse(publication.destination(root, current).exists())

    def test_missing_or_unreviewed_job_status_cannot_default_to_success(self):
        for status in ('', 'unknown', 'PASS'):
            with self.subTest(status=status), tempfile.TemporaryDirectory() as tmp:
                root = Path(tmp).resolve(); current, _, _ = fixtures.CapturePublicationTests().fixture(root)
                with patch.object(run, 'ROOT', root), patch.object(run.publication_context, 'checked', return_value=current), \
                     patch.dict(os.environ, {'CAPTURE_UPSTREAM_STATUS': status}, clear=True):
                    self.assertEqual(1, run.main(['finish', 'web', 'browser-shell']))
                self.assertFalse(publication.destination(root, current).exists())
