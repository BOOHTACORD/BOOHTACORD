import json
import tempfile
import unittest
import urllib.error
import urllib.request
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch
from .server import Guard
from .sample_failure import SampleFailure


class GuardWireTests(unittest.TestCase):
    def test_fault_status_requires_auth_and_reports_inactive(self):
        with tempfile.TemporaryDirectory() as directory:
            stack = SimpleNamespace(work=Path(directory))
            manifest = dict(Nonce='private', Accounts=[{}])
            with patch('tools.load.guard.server.verify_marker'):
                guard = Guard(stack, manifest)
                guard.start()
                try:
                    url = 'http://127.0.0.1:4890/fault-status/sfu_outage'
                    with self.assertRaises(urllib.error.HTTPError) as denied:
                        urllib.request.urlopen(url)
                    self.assertEqual(denied.exception.code, 403)
                    request = urllib.request.Request(url, headers={'X-Load-Nonce': 'private'})
                    with patch.object(guard.faults, 'active', return_value=False):
                        with self.assertRaises(urllib.error.HTTPError) as inactive:
                            urllib.request.urlopen(request)
                        self.assertEqual(inactive.exception.code, 409)
                    with patch.object(guard.faults, 'active', return_value=True):
                        with urllib.request.urlopen(request) as response:
                            self.assertEqual(response.status, 204)
                finally:
                    guard.close()

    def test_authentication_and_restore_during_health_failure(self):
        with tempfile.TemporaryDirectory() as directory:
            stack = SimpleNamespace(work=Path(directory))
            manifest = dict(Nonce='private', Accounts=[{}])
            with patch('tools.load.guard.server.verify_marker'), patch('tools.load.guard.server.owned'):
                guard = Guard(stack, manifest)
                guard.start()
                try:
                    req = urllib.request.Request('http://127.0.0.1:4890/snapshot')
                    with self.assertRaises(urllib.error.HTTPError) as denied:
                        urllib.request.urlopen(req)
                    self.assertEqual(denied.exception.code, 403)
                    with patch.object(guard, 'sample', side_effect=ValueError('health failure')):
                        req.add_header('X-Load-Nonce', 'private')
                        with self.assertRaises(urllib.error.HTTPError) as failed:
                            urllib.request.urlopen(req)
                        self.assertEqual(failed.exception.code, 503)
                        with patch.object(guard, 'sample', side_effect=SampleFailure('fixture_verification')):
                            with self.assertRaises(urllib.error.HTTPError) as categorized:
                                urllib.request.urlopen(req)
                            self.assertEqual(categorized.exception.code, 503)
                            self.assertEqual(categorized.exception.headers.get('X-QA-Guard-Stage'), 'fixture_verification')
                        restore = urllib.request.Request('http://127.0.0.1:4890/fault/restore',
                            method='POST', headers={'X-Load-Nonce': 'private'})
                        with urllib.request.urlopen(restore) as response:
                            self.assertEqual(response.status, 204)
                finally:
                    guard.close()


if __name__ == '__main__':
    unittest.main()
