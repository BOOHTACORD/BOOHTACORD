"""Losing the SSH client never proves that the remote installer stopped."""
from pathlib import Path
import json
import tempfile
import unittest
from unittest.mock import Mock,patch
from .interruption import idle_lock, checked_failure
from .test_faults import failed


class InterruptedInstallTests(unittest.TestCase):
    def test_failed_maintenance_check_retains_actual_signal_receipt_and_lock_observations(self):
        from . import interruption
        with tempfile.TemporaryDirectory() as temporary:
            work=Path(temporary);value=failed('remote_install','interrupted')
            value.update(source_revision='b'*40,controller_revision='c'*40)
            (work/'attempt-interrupted.json').write_text(json.dumps(value))
            report=dict(next='b'*40,controller='c'*40,observations=[])
            process=Mock();process.wait.return_value=143;process.poll.return_value=143
            with patch('tools.qa.trusted_delivery.positive.attempt',return_value=process),\
                    patch('tools.qa.trusted_delivery.positive.exchange',return_value=[]),\
                    patch('tools.qa.compatible_rollback.storage.observe',return_value={}),\
                    patch('tools.qa.compatible_rollback.storage.running',return_value={}),\
                    patch('tools.qa.compatible_rollback.storage.sql',return_value=b't'),\
                    patch.object(interruption,'idle_lock',side_effect=[False,True]),\
                    self.assertRaisesRegex(RuntimeError,'left maintenance active'):
                interruption.exercise(work,report)
            retained=json.loads((work/'delivery-runtime.json').read_text())['interruption_diagnostics']
            self.assertEqual('FAIL',retained['status'])
            self.assertEqual('maintenance_disabled',retained['stage'])
            self.assertEqual(143,retained['client_return_code'])
            self.assertEqual(value,retained['delivery'])
            self.assertIs(True,retained['lock_observed_held'])
            self.assertIs(True,retained['lock_observed_idle'])
            self.assertIs(True,retained['maintenance_active'])

    def test_requires_interruption_during_remote_install_for_exact_attempt_source(self):
        value = failed('remote_install', 'interrupted')
        checked_failure(value, 'a'*40, 'b'*40)
        for mode in ('wrong_phase', 'wrong_source', 'wrong_controller', 'timeout', 'green'):
            value = failed('remote_install', 'interrupted')
            if mode == 'wrong_phase': value = failed('transfer_bundle', 'interrupted')
            if mode == 'wrong_source': value['source_revision'] = 'c'*40
            if mode == 'wrong_controller': value['controller_revision'] = 'c'*40
            if mode == 'timeout': value['phases'][-1]['failure_code'] = 'timeout'
            if mode == 'green': value['status'] = 'PASS'
            with self.subTest(mode=mode), self.assertRaises(ValueError):
                checked_failure(value, 'a'*40, 'b'*40)

    @unittest.skipUnless(__import__('os').name == 'posix', 'Unix host lock')
    def test_remote_lock_must_be_observed_idle_without_waiting_or_unlocking_other_writer(self):
        import fcntl
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            with (root/'.install.lock').open('a') as held:
                fcntl.flock(held, fcntl.LOCK_EX | fcntl.LOCK_NB)
                self.assertFalse(idle_lock(root))
                fcntl.flock(held, fcntl.LOCK_UN)
                self.assertTrue(idle_lock(root))
