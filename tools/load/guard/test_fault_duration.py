import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch

from .faults import Faults


class FaultDurationTests(unittest.TestCase):
    def test_old_timer_cannot_restore_a_new_fault(self):
        with tempfile.TemporaryDirectory() as directory:
            faults = Faults(SimpleNamespace(work=Path(directory)))
            with patch('tools.load.guard.faults.owned', side_effect=lambda _, role: role), \
                 patch('tools.load.guard.faults.subprocess.run') as run, \
                 patch('tools.load.guard.faults.threading.Timer') as timer:
                faults.apply('sfu_outage', seconds=8)
                old_callback = timer.call_args.args[1]
                faults.apply('slow_telemetry', seconds=8)
                old_callback()
                self.assertEqual(faults.current, 'slow_telemetry')
                self.assertNotIn(['docker', 'unpause', 'tempo'], [c.args[0] for c in run.call_args_list])
                faults.restore()

    def test_requested_duration_is_bounded_and_controls_automatic_restore(self):
        with tempfile.TemporaryDirectory() as directory:
            faults = Faults(SimpleNamespace(work=Path(directory)))
            with patch('tools.load.guard.faults.owned', return_value='owned-sfu'), \
                 patch('tools.load.guard.faults.subprocess.run'), \
                 patch('tools.load.guard.faults.threading.Timer') as timer:
                faults.apply('sfu_outage', seconds=8)
                self.assertEqual(timer.call_args.args[0], 8)
                with self.assertRaises(ValueError):
                    faults.apply('sfu_outage', seconds=31)
                with self.assertRaises(ValueError):
                    faults.apply('sfu_outage', seconds=0)
                self.assertEqual(faults.current, 'sfu_outage')
                faults.restore()

    def test_database_lock_has_its_own_matching_server_side_timeout(self):
        with tempfile.TemporaryDirectory() as directory:
            faults = Faults(SimpleNamespace(work=Path(directory)))
            with patch('tools.load.guard.faults.owned', return_value='owned-db'), \
                 patch('tools.load.guard.faults.subprocess.Popen') as process, \
                 patch('tools.load.guard.faults.threading.Timer'):
                process.return_value.poll.return_value = 0
                faults.apply('db_pressure', seconds=8)
                command = process.call_args.args[0]
                self.assertIn('pg_sleep(8)', command[-1])
                self.assertIn("statement_timeout='8500ms'", command[-1])
                faults.restore()
