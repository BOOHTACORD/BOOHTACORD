import tempfile
import unittest
import urllib.error
import urllib.request
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch

from .server import Guard


class MaintenanceChangeTest(unittest.TestCase):
    def test_only_owned_authenticated_fixture_can_change_maintenance(self):
        with tempfile.TemporaryDirectory() as directory:
            stack = SimpleNamespace(work=Path(directory))
            manifest = dict(Nonce='private', Accounts=[{}])
            with patch('tools.load.guard.server.verify_marker'), patch('tools.load.guard.maintenance.verify_marker') as marker, \
                 patch('tools.load.guard.server.owned'), patch('tools.load.guard.maintenance.query', return_value='1') as query:
                guard = Guard(stack, manifest)
                guard.start()
                try:
                    request = urllib.request.Request('http://127.0.0.1:4890/maintenance/on', method='POST')
                    with self.assertRaises(urllib.error.HTTPError) as denied:
                        urllib.request.urlopen(request)
                    self.assertEqual(denied.exception.code, 403)
                    query.assert_not_called()
                    request.add_header('X-Load-Nonce', 'private')
                    with urllib.request.urlopen(request) as response:
                        self.assertEqual(response.status, 204)
                    self.assertGreaterEqual(marker.call_count, 1)
                    self.assertIn('maintenance_admission', query.call_args.args[1])
                    with self.assertRaises(urllib.error.HTTPError) as repeated:
                        urllib.request.urlopen(request)
                    self.assertEqual(repeated.exception.code, 503)
                finally:
                    guard.close()
                self.assertEqual(query.call_count, 2)
                self.assertIn('active=false', query.call_args.args[1])

    def test_changed_marker_prevents_mutation(self):
        with tempfile.TemporaryDirectory() as directory:
            stack = SimpleNamespace(work=Path(directory))
            manifest = dict(Nonce='private', Accounts=[{}])
            with patch('tools.load.guard.server.verify_marker'), \
                 patch('tools.load.guard.maintenance.verify_marker', side_effect=ValueError('foreign')), \
                 patch('tools.load.guard.maintenance.query') as query:
                guard = Guard(stack, manifest)
                guard.start()
                try:
                    request = urllib.request.Request('http://127.0.0.1:4890/maintenance/on', method='POST',
                                                     headers={'X-Load-Nonce': 'private'})
                    with self.assertRaises(urllib.error.HTTPError) as denied:
                        urllib.request.urlopen(request)
                    self.assertEqual(denied.exception.code, 503)
                    query.assert_not_called()
                finally:
                    guard.close()

    def test_already_active_fixture_is_not_reset(self):
        with tempfile.TemporaryDirectory() as directory:
            stack = SimpleNamespace(work=Path(directory))
            manifest = dict(Nonce='private', Accounts=[{}])
            with patch('tools.load.guard.server.verify_marker'), patch('tools.load.guard.maintenance.verify_marker'), \
                 patch('tools.load.guard.maintenance.query', return_value='0') as query:
                guard = Guard(stack, manifest)
                try:
                    with self.assertRaises(ValueError):
                        guard.maintenance.activate()
                finally:
                    guard.close()
                self.assertEqual(query.call_count, 1)


if __name__ == '__main__':
    unittest.main()
