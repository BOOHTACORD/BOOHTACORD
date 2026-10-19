"""Losing the SSH client never proves that the remote installer stopped."""
from pathlib import Path
import tempfile
import unittest
from .interruption import idle_lock, checked_failure
from .test_faults import failed


class InterruptedInstallTests(unittest.TestCase):
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
