import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch

from .faults import Faults


class FaultStatusTests(unittest.TestCase):
    def test_disk_fault_only_active_while_owned_file_exists(self):
        with tempfile.TemporaryDirectory() as directory:
            faults = Faults(SimpleNamespace(work=Path(directory)))
            self.assertFalse(faults.active('disk_pressure'))
            try:
                faults.apply('disk_pressure')
                self.assertTrue(faults.active('disk_pressure'))
                faults.pressure.unlink()
                self.assertFalse(faults.active('disk_pressure'))
            finally:
                faults.restore()

    def test_pause_must_still_be_paused_and_owned(self):
        with tempfile.TemporaryDirectory() as directory:
            faults = Faults(SimpleNamespace(work=Path(directory)))
            with patch('tools.load.guard.faults.owned', return_value='owned-sfu'), \
                 patch('tools.load.guard.faults.subprocess.run') as run:
                faults.apply('sfu_outage')
                try:
                    run.return_value.stdout = 'true\n'
                    self.assertTrue(faults.active('sfu_outage'))
                    run.return_value.stdout = 'false\n'
                    self.assertFalse(faults.active('sfu_outage'))
                finally:
                    faults.restore()

    def test_database_process_alone_is_not_proof_of_a_lock(self):
        with tempfile.TemporaryDirectory() as directory:
            faults = Faults(SimpleNamespace(work=Path(directory)))
            with patch('tools.load.guard.faults.owned', return_value='owned-db'), \
                 patch('tools.load.guard.faults.subprocess.Popen') as process, \
                 patch('tools.load.guard.faults.query', return_value='f') as query:
                process.return_value.poll.return_value = None
                faults.apply('db_pressure')
                try:
                    self.assertFalse(faults.active('db_pressure'))
                    query.return_value = 't'
                    self.assertTrue(faults.active('db_pressure'))
                    process.return_value.poll.return_value = 0
                    self.assertFalse(faults.active('db_pressure'))
                finally:
                    faults.restore()

    def test_restore_during_external_inspection_cannot_report_active(self):
        with tempfile.TemporaryDirectory() as directory:
            faults = Faults(SimpleNamespace(work=Path(directory)))
            with patch('tools.load.guard.faults.owned', return_value='owned-sfu'), \
                 patch('tools.load.guard.faults.subprocess.run') as run:
                faults.apply('sfu_outage')
                def inspect(*args, **kwargs):
                    faults.restore()
                    return SimpleNamespace(stdout='true\n')
                run.side_effect = inspect
                # Avoid recursively intercepting restore's unpause.
                def once(*args, **kwargs):
                    run.side_effect = None
                    return inspect(*args, **kwargs)
                run.side_effect = once
                self.assertFalse(faults.active('sfu_outage'))


if __name__ == '__main__':
    unittest.main()
