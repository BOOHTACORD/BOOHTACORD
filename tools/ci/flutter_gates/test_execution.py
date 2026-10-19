"""A failed command or changed source cannot leave a stale successful profile record."""
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
from . import run
from .profiles import OPERATIONS


class ExecutionTests(unittest.TestCase):
    def test_failed_profile_overwrites_stale_pass_before_execution(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary).resolve()
            target = root / '.out/ci/flutter-parts/dart.json'
            target.parent.mkdir(parents=True); target.write_text('{"status":"PASS"}')
            with patch.dict('os.environ'), patch.object(run, 'ROOT', root), patch('sys.argv', ['flutter-profile', 'dart']), \
                 patch.object(run.source, 'context', return_value=('a' * 40, '123', '1', 'flutter')), \
                 patch.object(run.source, 'verify'), \
                 patch.object(run.profiles, 'execute', side_effect=RuntimeError('intentional failure')):
                with self.assertRaises(RuntimeError): run.main()
            self.assertEqual('FAIL', json.loads(target.read_text())['status'])

    def test_source_is_checked_after_execution_before_artifacts_can_attest_success(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary).resolve()
            with patch.object(run, 'ROOT', root), patch('sys.argv', ['flutter-profile', 'android']), \
                 patch.object(run.source, 'context', return_value=('a' * 40, '123', '1', 'flutter')), \
                 patch.object(run.source, 'verify', side_effect=[None, ValueError('source changed')]) as verify, \
                 patch.object(run.profiles, 'execute', return_value=list(OPERATIONS['android'])), \
                 patch.object(run.artifacts, 'android') as artifacts:
                with self.assertRaises(ValueError): run.main()
                self.assertEqual(2, verify.call_count); artifacts.assert_not_called()
            self.assertEqual('FAIL', json.loads((root / '.out/ci/flutter-parts/android.json').read_text())['status'])
