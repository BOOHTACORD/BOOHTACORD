import unittest

from tools.qa.critical_client_acceptance.issue785_android_flutter_uplink_pair import (
    MIN_BACKGROUND_SECONDS,
    receiver_has_foreground_uplink,
    receiver_progressed_during_background,
    validate_background_seconds,
)


class Issue785AndroidFlutterUplinkPairTest(unittest.TestCase):
    def test_reproduction_window_is_two_minutes(self):
        self.assertEqual(MIN_BACKGROUND_SECONDS, 120)
        self.assertEqual(validate_background_seconds(120), 120)

    def test_rejects_shorter_than_reproduction_window(self):
        with self.assertRaises(ValueError):
            validate_background_seconds(119)

    def test_requires_independent_receiver_packets_to_advance_in_background(self):
        samples = [
            {'observed_at_unix_ms': 1000, 'inbound_audio_packets': 20, 'inbound_audio_bytes': 800},
            {'observed_at_unix_ms': 31000, 'inbound_audio_packets': 320, 'inbound_audio_bytes': 12800},
            {'observed_at_unix_ms': 61000, 'inbound_audio_packets': 620, 'inbound_audio_bytes': 24800},
            {'observed_at_unix_ms': 91000, 'inbound_audio_packets': 920, 'inbound_audio_bytes': 36800},
            {'observed_at_unix_ms': 121000, 'inbound_audio_packets': 1220, 'inbound_audio_bytes': 48800},
        ]

        self.assertTrue(receiver_progressed_during_background(samples, 2000, 120000))

    def test_does_not_accept_packets_that_only_advanced_before_or_after_background(self):
        samples = [
            {'observed_at_unix_ms': 1000, 'inbound_audio_packets': 20, 'inbound_audio_bytes': 800},
            {'observed_at_unix_ms': 1500, 'inbound_audio_packets': 90, 'inbound_audio_bytes': 3600},
            {'observed_at_unix_ms': 121000, 'inbound_audio_packets': 90, 'inbound_audio_bytes': 3600},
            {'observed_at_unix_ms': 122000, 'inbound_audio_packets': 250, 'inbound_audio_bytes': 10000},
        ]

        self.assertFalse(receiver_progressed_during_background(samples, 2000, 120000))

    def test_foreground_pair_requires_independent_inbound_audio_rtp(self):
        self.assertTrue(receiver_has_foreground_uplink({
            'inbound_audio_tracks': 1,
            'inbound_audio_packets': 2,
            'inbound_audio_bytes': 48,
        }))
        self.assertFalse(receiver_has_foreground_uplink({
            'inbound_audio_tracks': 0,
            'inbound_audio_packets': 0,
            'inbound_audio_bytes': 0,
        }))
        self.assertFalse(receiver_has_foreground_uplink({
            'inbound_audio_tracks': 1,
            'inbound_audio_packets': 2,
            'inbound_audio_bytes': 0,
        }))


if __name__ == '__main__':
    unittest.main()
