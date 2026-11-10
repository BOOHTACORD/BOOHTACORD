import sys
import unittest
from unittest.mock import patch

from tools.ci.native import contracts


class RealtimeMigrationGateTest(unittest.TestCase):
    def test_contract_check_runs_realtime_migration_guard(self):
        with patch.object(contracts, 'run') as run:
            contracts.main()
        run.assert_any_call(sys.executable, '-m', 'tools.verify.realtime_migration.guard')


if __name__ == '__main__':
    unittest.main()
