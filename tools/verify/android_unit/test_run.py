import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
from . import run
from .inventory import EXPECTED, verify_sources


class RunnerTests(unittest.TestCase):
    def test_reviewed_sources_still_contain_all_forty_cases(self):
        verify_sources(run.ROOT)
        self.assertEqual(40, sum(sum(row.values()) for row in EXPECTED.values()))

    def test_modes_run_all_tasks_and_require_each_plugin_result(self):
        for mode in ('legacy', 'builtin'):
            with self.subTest(mode=mode), tempfile.TemporaryDirectory() as directory, \
                 patch.object(run, 'ROOT', Path(directory)), patch.object(run, 'verify_sources'), \
                 patch.object(run.subprocess, 'run') as call, \
                 patch.object(run, 'validate', side_effect=list(EXPECTED.values())) as validate:
                result = run.execute(mode)
                self.assertEqual('PASS', result['status'])
                self.assertEqual(40, result['tests'])
                command = call.call_args.args[0]
                self.assertTrue(all(':' + p + ':testDebugUnitTest' in command for p in EXPECTED))
                self.assertIn('--rerun-tasks', command)
                self.assertIn('-Pandroid.builtInKotlin=' + str(mode == 'builtin').lower(), command)
                self.assertEqual(3, validate.call_count)
                with self.assertRaises(FileExistsError): run.execute(mode)

    def test_gradle_failure_or_missing_class_leaves_failure_receipt(self):
        for stage in ('gradle', 'xml'):
            with tempfile.TemporaryDirectory() as directory, patch.object(run, 'ROOT', Path(directory)), \
                 patch.object(run, 'verify_sources'), patch.object(run.subprocess, 'run') as call, \
                 patch.object(run, 'validate', side_effect=ValueError('missing class')):
                if stage == 'gradle': call.side_effect = RuntimeError('gradle failed')
                with self.assertRaises((RuntimeError, ValueError)): run.execute('legacy')
                receipt = Path(directory) / '.out/checks/android-unit/legacy/result.json'
                self.assertEqual('FAIL', json.loads(receipt.read_text())['status'])
