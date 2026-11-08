"""Network and ownership guarantees for the real upload-reservation stack."""
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from .stack import UploadStack


class UploadStackTests(unittest.TestCase):
    def test_api_publishes_health_port_and_reaches_livekit_through_owned_bridge(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            stack = UploadStack(root, root, 2 * 1024**3)
            with patch.object(stack, 'container') as container, \
                    patch('tools.qa.upload_reservations.stack.run') as run, \
                    patch('tools.qa.upload_reservations.stack.output', return_value='arm64') as output, \
                    patch('tools.qa.upload_reservations.stack.ready') as ready:
                stack.restart()

            output.assert_called_once_with('docker', 'info', '--format', '{{.Architecture}}')
            build = next(call for call in run.call_args_list if call.args[:2] == ('go', 'build'))
            self.assertEqual(build.kwargs['env']['GOARCH'], 'arm64')
            args = container.call_args.args
            pairs = list(zip(args, args[1:]))
            self.assertEqual(args[:2], ('api', 'postgres:17.6-alpine'))
            self.assertTrue(container.call_args.kwargs.get('network', True))
            self.assertIn(('--publish', '127.0.0.1:4820:8080'), pairs)
            self.assertIn(('--add-host', 'host.docker.internal:host-gateway'), pairs)
            ready.assert_called_once_with('http://127.0.0.1:4820/api/v1/health')
