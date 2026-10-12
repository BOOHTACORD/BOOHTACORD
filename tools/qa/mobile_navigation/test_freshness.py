"""A failed new native run cannot reuse an earlier PASS receipt or captures."""
import json
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from tools.qa.mobile_navigation import run_native as navigation
from tools.qa.message_actions import run_native as actions


class NativeReceiptFreshnessTests(unittest.TestCase):
    workers = ((navigation, 'mobile_navigation', 'qa292-20261012'), (actions, 'message_actions', 'qa293-20261012'))

    def failed_preflight(self, module, folder, case, source_mismatch):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            output = root/'.out'/case/'android'
            output.mkdir(parents=True)
            (output/'runtime.json').write_text(json.dumps({'status': 'PASS', 'checks': {'old': 'PASS'}}))
            (output/'scenario.json').write_text(json.dumps({'status': 'PASS', 'checks': {'old': 'PASS'}}))
            (output/'previous-capture.png').write_bytes(b'old synthetic capture placeholder')
            def command_result(command, **kwargs):
                return b'diff' if command[:3] == ['git', 'diff', '--binary'] else 'candidate'
            device_error = None if source_mismatch else ValueError('Owned preflight fixture')
            with patch.object(module, '__file__', str(root/'tools/qa'/folder/'run_native.py')), patch.object(sys, 'argv', ['qa', '--platform', 'android', '--device', 'emulator-5556']), patch.object(module, 'verify_device', side_effect=device_error), patch.object(module.subprocess, 'check_output', side_effect=command_result), patch.object(module, 'source_manifest', side_effect=[{'one.dart': 'candidate'}, {'one.dart': 'stale'}]), patch.object(module, 'run_owned') as driver, patch.object(module, 'Stack') as stack:
                with self.assertRaises(ValueError):
                    module.main()
            driver.assert_not_called()
            stack.assert_not_called()
            receipt = json.loads((output/'runtime.json').read_text())
            self.assertEqual(receipt['status'], 'FAIL')
            self.assertEqual(receipt['error_type'], 'ValueError')
            self.assertEqual(receipt['phase'], 'preflight')
            self.assertNotIn('checks', receipt)
            self.assertFalse((output/'scenario.json').exists())
            self.assertFalse((output/'previous-capture.png').exists())
            archived = list((output.parent/'previous-harness-runs'/'android').glob('*/runtime.json'))
            self.assertEqual(len(archived), 1)
            self.assertEqual(json.loads(archived[0].read_text())['status'], 'PASS')

    def test_missing_device_archives_previous_pass_and_records_new_failure(self):
        for module, folder, case in self.workers:
            with self.subTest(worker=folder):
                self.failed_preflight(module, folder, case, source_mismatch=False)

    def test_exception_after_written_outcome_never_leaves_pass(self):
        for module, folder, case in self.workers:
            with self.subTest(worker=folder), tempfile.TemporaryDirectory() as temporary:
                root = Path(temporary)
                def late_failure(args, output):
                    (output/'runtime.json').write_text(json.dumps({'status': 'PASS', 'phase': 'driver outcome'}))
                    raise RuntimeError('Owned synthetic post-driver failure')
                with patch.object(module, '__file__', str(root/'tools/qa'/folder/'run_native.py')), patch.object(sys, 'argv', ['qa', '--platform', 'android']), patch.object(module, 'execute', side_effect=late_failure):
                    with self.assertRaises(RuntimeError):
                        module.main()
                receipt = json.loads((root/'.out'/case/'android'/'runtime.json').read_text())
                self.assertEqual(receipt['status'], 'FAIL')
                self.assertEqual(receipt['error_type'], 'RuntimeError')
                self.assertEqual(receipt['phase'], 'driver outcome')

    def test_source_mismatch_archives_previous_pass_and_records_new_failure(self):
        for module, folder, case in self.workers:
            with self.subTest(worker=folder):
                self.failed_preflight(module, folder, case, source_mismatch=True)


if __name__ == '__main__':
    unittest.main()
