import unittest
from unittest.mock import patch, MagicMock
from .livekit_linux import make_server_config, docker_command, private_sfu


class LinuxLiveKitIsolationTests(unittest.TestCase):
    def test_ports_are_bound_to_loopback_and_selected_private_interface(self):
        cmd = docker_command('boohta-test', '/tmp/fixture.yaml', '10.1.2.3')
        self.assertIn('127.0.0.1:17880:7880/tcp', cmd)
        self.assertIn('10.1.2.3:7882:7882/udp', cmd)
        self.assertNotIn('--dev', cmd)
        with self.assertRaises(ValueError): docker_command('boohta-test', '/tmp/fixture.yaml', '8.8.8.8')

    def test_failure_cleans_container_and_uses_new_credentials(self):
        response = MagicMock(); response.__enter__.return_value.status = 200
        with patch('tools.audio.research_dfn_web.livekit_linux.local_address', return_value='10.1.2.3'), \
             patch('tools.audio.research_dfn_web.livekit_linux.urlopen', return_value=response), \
             patch('tools.audio.research_dfn_web.livekit_linux.subprocess.run') as run:
            with self.assertRaises(RuntimeError):
                with private_sfu({'RNNOISE_LIVEKIT_URL': 'wss://invalid'}) as env:
                    self.assertEqual(env['RNNOISE_LIVEKIT_URL'], 'ws://127.0.0.1:17880')
                    self.assertNotEqual(env['RNNOISE_LIVEKIT_API_KEY'], 'devkey')
                    raise RuntimeError('consumer failure')
            self.assertEqual(run.call_count, 2)
            self.assertEqual(run.call_args_list[-1].args[0][:3], ['docker', 'rm', '-f'])

    def test_start_failure_still_attempts_container_cleanup(self):
        with patch('tools.audio.research_dfn_web.livekit_linux.local_address', return_value='10.1.2.3'), \
             patch('tools.audio.research_dfn_web.livekit_linux.subprocess.run', side_effect=[RuntimeError('start'), None]) as run:
            with self.assertRaises(RuntimeError):
                with private_sfu({}): pass
            self.assertEqual(run.call_count, 2)
            self.assertEqual(run.call_args_list[-1].args[0][:3], ['docker', 'rm', '-f'])

    def test_random_credential_inputs_are_bounded(self):
        value = make_server_config('probe0123', 'secret0123')
        self.assertIn('probe0123: secret0123', value)
        self.assertIn('udp_port: 7882', value)
        with self.assertRaises(ValueError): make_server_config('bad\nkey', 'secret0123')
