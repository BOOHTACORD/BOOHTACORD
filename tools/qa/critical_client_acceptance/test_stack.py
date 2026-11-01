import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch
from tools.audio.livekit_fixture import IMAGE
from .stack import EGRESS_IMAGE, REDIS_IMAGE, Stack


class LoopbackTransportTests(unittest.TestCase):
    def test_owned_sfu_listens_on_bridge_and_advertises_loopback_candidates(self):
        with tempfile.TemporaryDirectory() as directory:
            work = Path(directory)
            stack = Stack(work, work)
            with patch.dict('os.environ', {'BOOHTACORD_QA_EGRESS_PLATFORM': 'linux/amd64'}), \
                    patch('tools.qa.critical_client_acceptance.stack.local_docker'), \
                    patch('tools.qa.critical_client_acceptance.stack.ports_available'), \
                    patch('tools.qa.critical_client_acceptance.stack.ready'), \
                    patch('tools.qa.critical_client_acceptance.stack.Base.start'), \
                    patch('tools.qa.critical_client_acceptance.stack.subprocess.run', return_value=type('Result', (), {'returncode': 0, 'stdout': '', 'stderr': 'service ready'})()), \
                    patch('tools.qa.critical_client_acceptance.stack.time.sleep'), \
                    patch.object(stack, 'container') as container:
                stack.start()
            config = (work/'livekit.yaml').read_text()
            egress_config = (work/'egress.yaml').read_text()
            self.assertIn('enable_loopback_candidate: true', config)
            self.assertIn('includes: ["eth0"]', config)
            self.assertIn('bind_addresses: ["0.0.0.0"]', config)
            self.assertIn(f'http://{stack.owner}-api:8080/internal/livekit/roster', config)
            self.assertIn(f'address: {stack.owner}-redis:6379', config)
            self.assertIn(f'ws_url: ws://{stack.owner}-sfu:4880', egress_config)
            self.assertIn(f'address: {stack.owner}-redis:6379', egress_config)
            self.assertEqual(stack.environment['SCREEN_PREVIEW_DIRECTORY'], '/screen-previews')
            self.assertEqual(stack.environment['LIVEKIT_PRIVATE_HTTP_URL'],
                             f'http://{stack.owner}-sfu:4880')
            calls = {call.args[0]: call for call in container.call_args_list}
            self.assertEqual(calls['redis'].args[:2], ('redis', REDIS_IMAGE))
            self.assertEqual(calls['egress'].args[:2], ('egress', EGRESS_IMAGE))
            self.assertIn('--platform=linux/amd64', calls['egress'].args)
            args = calls['sfu'].args
            pairs = list(zip(args, args[1:]))
            self.assertEqual(args[:2], ('sfu', IMAGE))
            self.assertTrue(calls['sfu'].kwargs.get('network', True))
            self.assertIn(('--publish', '127.0.0.1:4880:4880/tcp'), pairs)
            self.assertIn(('--publish', '127.0.0.1:4881:4881/tcp'), pairs)
            self.assertIn(('--publish', '127.0.0.1:4882:4882/udp'), pairs)
            self.assertEqual(calls['sfu'].kwargs['command'],
                             ('--config', '/qa.yaml', '--node-ip', '127.0.0.1'))
            self.assertIn(f'{stack.preview_root}:/screen-previews', calls['egress'].args)
            self.assertEqual(calls['egress'].kwargs['memory'], '2g')
