import unittest

from tools.qa.critical_client_acceptance.issue785_android_flutter_uplink_pair import (
    MIN_BACKGROUND_SECONDS,
    display_is_asleep,
    receiver_has_foreground_uplink,
    receiver_blackhole_recovery,
    receiver_progressed_during_background,
    validate_blackhole_seconds,
    validate_background_seconds,
    parse_blackhole_drop_counters,
)


class Issue785AndroidFlutterUplinkPairTest(unittest.TestCase):
    def test_reproduction_window_is_two_minutes(self):
        self.assertEqual(MIN_BACKGROUND_SECONDS, 120)
        self.assertEqual(validate_background_seconds(120), 120)

    def test_rejects_shorter_than_reproduction_window(self):
        with self.assertRaises(ValueError):
            validate_background_seconds(119)

    def test_network_blackhole_fits_inside_two_minute_background_window(self):
        self.assertEqual(validate_blackhole_seconds(120, 30), 30)
        self.assertEqual(validate_blackhole_seconds(120, 0), 0)

    def test_rejects_blackhole_that_does_not_leave_time_to_resume(self):
        with self.assertRaises(ValueError):
            validate_blackhole_seconds(120, 115)

    def test_reads_blackhole_drop_counters_for_loopback_api_and_media(self):
        output = '''Chain OUTPUT (policy ACCEPT 12 packets, 800 bytes)
    pkts      bytes target     prot opt in     out     source               destination
      739   101896 DROP       17   --  *      *       0.0.0.0/0            127.0.0.1            udp dpt:4882
      613   702769 DROP       6    --  *      *       0.0.0.0/0            127.0.0.1            multiport dports 4810,4881
'''
        self.assertEqual(parse_blackhole_drop_counters(output), {
            'udp_4882': {'packets': 739, 'bytes': 101896},
            'tcp_4810_4881': {'packets': 613, 'bytes': 702769},
        })

    def test_detects_screen_off_power_state(self):
        self.assertTrue(display_is_asleep('mWakefulness=Asleep\n'))
        self.assertFalse(display_is_asleep('mWakefulness=Awake\n'))
        self.assertFalse(display_is_asleep(''))

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

    def test_requires_blackhole_pause_and_rtp_recovery_within_fifteen_seconds(self):
        samples = [
            {'observed_at_unix_ms': 1000, 'inbound_audio_tracks': 1, 'inbound_audio_packets': 20, 'inbound_audio_bytes': 800},
            {'observed_at_unix_ms': 5000, 'inbound_audio_tracks': 1, 'inbound_audio_packets': 60, 'inbound_audio_bytes': 2400},
            {'observed_at_unix_ms': 7000, 'inbound_audio_tracks': 1, 'inbound_audio_packets': 60, 'inbound_audio_bytes': 2400},
            {'observed_at_unix_ms': 9000, 'inbound_audio_tracks': 0, 'inbound_audio_packets': 0, 'inbound_audio_bytes': 0},
            {'observed_at_unix_ms': 12000, 'inbound_audio_tracks': 0, 'inbound_audio_packets': 0, 'inbound_audio_bytes': 0},
            {'observed_at_unix_ms': 14000, 'inbound_audio_tracks': 1, 'inbound_audio_packets': 12, 'inbound_audio_bytes': 600},
            {'observed_at_unix_ms': 16000, 'inbound_audio_tracks': 1, 'inbound_audio_packets': 22, 'inbound_audio_bytes': 1300},
        ]

        result = receiver_blackhole_recovery(samples, 5000, 13000)
        self.assertIsNotNone(result)
        self.assertEqual(result['recovery_seconds'], 1.0)
        self.assertEqual(result['receiver_last_during_blackhole']['inbound_audio_packets'], 0)

    def test_blackhole_recovery_fails_if_packets_never_pause_or_resume(self):
        continuous = [
            {'observed_at_unix_ms': 1000, 'inbound_audio_tracks': 1, 'inbound_audio_packets': 20, 'inbound_audio_bytes': 800},
            {'observed_at_unix_ms': 6000, 'inbound_audio_tracks': 1, 'inbound_audio_packets': 70, 'inbound_audio_bytes': 2800},
            {'observed_at_unix_ms': 12000, 'inbound_audio_tracks': 1, 'inbound_audio_packets': 130, 'inbound_audio_bytes': 5200},
        ]
        no_recovery = [
            {'observed_at_unix_ms': 1000, 'inbound_audio_tracks': 1, 'inbound_audio_packets': 20, 'inbound_audio_bytes': 800},
            {'observed_at_unix_ms': 6000, 'inbound_audio_tracks': 1, 'inbound_audio_packets': 20, 'inbound_audio_bytes': 800},
            {'observed_at_unix_ms': 12000, 'inbound_audio_tracks': 0, 'inbound_audio_packets': 0, 'inbound_audio_bytes': 0},
        ]
        self.assertIsNone(receiver_blackhole_recovery(continuous, 5000, 10000))
        self.assertIsNone(receiver_blackhole_recovery(no_recovery, 5000, 10000))

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
