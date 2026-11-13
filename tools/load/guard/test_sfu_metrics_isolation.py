import unittest
from types import SimpleNamespace
from unittest.mock import patch

from .server import Guard


class SFUMetricsIsolationTests(unittest.TestCase):
    def test_known_sfu_fault_does_not_block_resource_guard_on_optional_metrics(self):
        guard = Guard.__new__(Guard)
        guard.stack = object()
        guard.resources = object()
        guard.faults = SimpleNamespace(sfu_outage_active=lambda: True)
        guard.manifest = dict(Owner='qa', Origin='https://localhost:4810',
                              Commit='commit', Accounts=[], Nonce='nonce')
        resources = dict(CPUPercent=10, RSSBytes=1024, FreeBytes=1 << 30)
        with patch('tools.load.guard.server.checked_inputs', return_value=resources), \
                patch('tools.load.guard.server.snapshot') as snapshot:
            result = guard.sample()
        snapshot.assert_not_called()
        self.assertEqual(result['MetricsStatus'], 'UNAVAILABLE')
        self.assertEqual(result['Metrics'], {})
        self.assertEqual(result['CPUPercent'], 10)


if __name__ == '__main__':
    unittest.main()
