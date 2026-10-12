import socket
from pathlib import Path
import stat
import tempfile
import unittest

from .run import PORTS, REPLACEMENTS, private_json
from .worker import require_ports_available


class MacUiSafetyTests(unittest.TestCase):
    def test_parallel_worker_has_unique_six_ports(self):
        self.assertEqual(len(set(PORTS.values())), 6)
        self.assertTrue(all(4800 < port < 4900 for port in PORTS.values()))
        self.assertEqual(REPLACEMENTS['4881'], '4891')
        self.assertEqual(REPLACEMENTS['4882'], '4895')
        self.assertFalse({4810, 4812, 4820, 4880, 4881, 4882} & set(PORTS.values()))

    def test_existing_udp_listener_is_not_replaced(self):
        with socket.socket(socket.AF_INET,socket.SOCK_DGRAM) as listener:
            listener.bind(("127.0.0.1",0))
            with self.assertRaises(OSError):
                require_ports_available({"sfu_udp":listener.getsockname()[1]})

    def test_private_fixture_configuration_is_owner_only(self):
        with tempfile.TemporaryDirectory() as temp:
            path=Path(temp)/'configuration.json'
            private_json(path, {'password':'disposable-test-only'})
            self.assertEqual(stat.S_IMODE(path.stat().st_mode), 0o600)
            self.assertEqual(path.read_text(), '{"password": "disposable-test-only"}')

    def test_configuration_collision_does_not_overwrite_existing_file(self):
        with tempfile.TemporaryDirectory() as temp:
            path=Path(temp)/'configuration.json'
            path.write_text('existing')
            with self.assertRaises(FileExistsError):
                private_json(path, {'password':'disposable-test-only'})
            self.assertEqual(path.read_text(), 'existing')


if __name__ == '__main__':
    unittest.main()
