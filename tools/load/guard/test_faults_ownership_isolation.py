import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch

from .faults import Faults


class DatabaseFaultIsolationTests(unittest.TestCase):
    def test_database_fault_avoids_guard_identity_table_and_verifies_same_lock(self):
        with tempfile.TemporaryDirectory() as directory:
            faults = Faults(SimpleNamespace(work=Path(directory)))
            with patch('tools.load.guard.faults.owned', return_value='owned-db'), \
                    patch('tools.load.guard.faults.subprocess.Popen') as process, \
                    patch('tools.load.guard.faults.query', return_value='t') as query:
                process.return_value.poll.return_value = None
                try:
                    faults.apply('db_pressure')
                    command = process.call_args.args[0]
                    statement = command[command.index('-c') + 1]
                    self.assertIn('LOCK channels IN ACCESS EXCLUSIVE MODE', statement)
                    self.assertNotIn('LOCK users ', statement)
                    self.assertTrue(faults.active('db_pressure'))
                    self.assertIn("l.relation='channels'::regclass", query.call_args.args[1])
                finally:
                    faults.restore()


if __name__ == '__main__':
    unittest.main()
