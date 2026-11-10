import unittest
from pathlib import Path

from .catalog import OPERATIONS

ROOT = Path(__file__).resolve().parents[3]


class NodeInventoryTest(unittest.TestCase):
    def test_required_realtime_fixture_tests_exist_in_lifecycle_gate(self):
        commands = [cmd for cmd in OPERATIONS['lifecycle'] if cmd[:2] == ['node', '--test']]
        self.assertEqual(len(commands), 1)
        paths = commands[0][2:]
        for path in paths:
            with self.subTest(path=path):
                self.assertTrue((ROOT / path).is_file())
        self.assertIn('clients/web/artifacts/design-v2/reference-live-state.test.mjs', paths)
        self.assertIn('tools/qa/critical_client_acceptance/roster_websocket_observer.test.mjs', paths)
        self.assertIn('tools/qa/critical_client_acceptance/roster_websocket_network.test.mjs', paths)


if __name__ == '__main__':
    unittest.main()
