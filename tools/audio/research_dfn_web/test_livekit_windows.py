import unittest
from .livekit_windows import is_private_test_ip, make_config, probe_environment, bounded_timeout

class IsolatedServerConfigTest(unittest.TestCase):
    def test_browser_deadline_is_bounded(self):
        self.assertEqual(bounded_timeout('150'), 150)
        self.assertEqual(bounded_timeout('1900'), 1900)
        for value in ('0', '1901', '-1', 'abc'):
            with self.subTest(value=value), self.assertRaises(ValueError): bounded_timeout(value)
    def test_private_interface_must_not_be_loopback_or_public(self):
        self.assertTrue(is_private_test_ip('192.168.4.7'))
        self.assertTrue(is_private_test_ip('10.0.0.2'))
        self.assertFalse(is_private_test_ip('127.0.0.1'))
        self.assertFalse(is_private_test_ip('8.8.8.8'))
        self.assertFalse(is_private_test_ip('192.0.2.1'))

    def test_server_url_cannot_escape_to_inherited_environment(self):
        inherited = {'RNNOISE_LIVEKIT_URL': 'wss://example.invalid'}
        env = probe_environment(inherited, 'test-key', 'test-secret')
        self.assertEqual(env['RNNOISE_LIVEKIT_URL'], 'ws://127.0.0.1:17880')
        self.assertEqual(env['RNNOISE_LIVEKIT_API_KEY'], 'test-key')
        self.assertEqual(env['RNNOISE_LIVEKIT_API_SECRET'], 'test-secret')
        self.assertEqual(inherited['RNNOISE_LIVEKIT_URL'], 'wss://example.invalid')

    def test_config_restricts_signaling_and_rtc_candidates(self):
        result = make_config('192.168.4.7', 'test-key', 'test-secret')
        self.assertIn('127.0.0.1', result)
        self.assertIn('192.168.4.7/32', result)
        self.assertIn('use_external_ip: false', result)
        with self.assertRaises(ValueError): make_config('8.8.8.8', 'test-key', 'test-secret')

if __name__ == '__main__': unittest.main()
