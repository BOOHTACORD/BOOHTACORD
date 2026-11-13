import tempfile
import unittest
import urllib.error
import urllib.request
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch

from .server import Guard


class DurationWireTests(unittest.TestCase):
    def test_duration_is_forwarded_only_with_valid_authentication(self):
        with tempfile.TemporaryDirectory() as directory:
            stack = SimpleNamespace(work=Path(directory))
            with patch('tools.load.guard.server.verify_marker'), patch('tools.load.guard.server.owned'):
                guard = Guard(stack, dict(Nonce='private', Accounts=[{}]))
                guard.start()
                try:
                    url = 'http://127.0.0.1:4890/fault/sfu_outage'
                    headers = {'X-Load-Nonce': 'private', 'X-QA-Fault-Seconds': '8'}
                    request = urllib.request.Request(url, method='POST', headers=headers)
                    with patch.object(guard.faults, 'apply') as apply:
                        with urllib.request.urlopen(request) as response:
                            self.assertEqual(response.status, 204)
                        apply.assert_called_once_with('sfu_outage', seconds=8)
                    headers['X-QA-Fault-Seconds'] = '31'
                    request = urllib.request.Request(url, method='POST', headers=headers)
                    with self.assertRaises(urllib.error.HTTPError) as rejected:
                        urllib.request.urlopen(request)
                    self.assertEqual(rejected.exception.code, 503)
                finally:
                    guard.close()
