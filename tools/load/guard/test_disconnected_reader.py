import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import Mock, patch
from tools.load.guard.server import Guard

class GuardDisconnectedReaderTest(unittest.TestCase):
    def test_disconnected_snapshot_reader_does_not_attempt_second_response(self):
        stack = SimpleNamespace(work=Path('.'))
        manifest = dict(Nonce='private', Accounts=[{}])
        with patch('tools.load.guard.server.verify_marker'):
            guard = Guard(stack, manifest)
        try:
            handler = object.__new__(guard.server.RequestHandlerClass)
            handler.headers = {'X-Load-Nonce': 'private'}
            handler.path = '/snapshot'
            handler.send_response = Mock()
            handler.send_header = Mock()
            handler.end_headers = Mock()
            handler.send_error = Mock(side_effect=AssertionError('must not write another response'))
            handler.wfile = SimpleNamespace(write=Mock(side_effect=BrokenPipeError()))
            with patch.object(guard, 'sample', return_value={'ok': True}):
                handler.do_GET()
            handler.send_error.assert_not_called()
        finally:
            guard.server.server_close()
