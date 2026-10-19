"""A failed or incomplete legacy phase cannot become a successful timing control."""
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
from . import legacy_run


class LegacyRunTests(unittest.TestCase):
    def test_failed_original_dart_phase_clears_a_stale_success(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary).resolve(); target = root / '.out/ci/flutter-legacy.json'
            target.parent.mkdir(parents=True); target.write_text('{"status":"PASS"}')
            with patch.dict('os.environ'), patch.object(legacy_run, 'ROOT', root), \
                 patch('sys.argv', ['legacy', 'dart']), \
                 patch.object(legacy_run.source, 'context', return_value=('a' * 40, '123', '1', 'shadow-old-1')), \
                 patch.object(legacy_run.source, 'verify'), \
                 patch.object(legacy_run.legacy, 'dart', side_effect=RuntimeError('intentional')):
                with self.assertRaises(RuntimeError): legacy_run.main()
            self.assertEqual('FAIL', json.loads(target.read_text())['status'])

    def test_finish_without_successful_real_phases_cannot_measure_artifacts(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary).resolve()
            with patch.object(legacy_run, 'ROOT', root), patch('sys.argv', ['legacy', 'finish']), \
                 patch.object(legacy_run.source, 'context', return_value=('a' * 40, '123', '1', 'shadow-old-1')), \
                 patch.object(legacy_run.source, 'verify'), patch.object(legacy_run.artifacts, 'android') as apk:
                with self.assertRaises(ValueError): legacy_run.main()
                apk.assert_not_called()
