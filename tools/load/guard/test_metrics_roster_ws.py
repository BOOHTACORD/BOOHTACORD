import unittest
from tools.load.guard.metrics import aggregate

class RosterWSMetricProjectionTest(unittest.TestCase):
    def test_only_bounded_roster_outcomes_and_gauges_are_observed(self):
        values=aggregate('''voice_platform_voice_roster_ws_subscribers 3
voice_platform_voice_roster_ws_initial_total{outcome="success"} 2
voice_platform_voice_roster_ws_delivery_total{outcome="unavailable"} 1
voice_platform_voice_roster_ws_refresh_total{outcome="failure"} 1
voice_platform_voice_roster_ws_delivery_total{outcome="private_identifier"} 5
voice_platform_voice_roster_ws_last_success_timestamp_seconds 123
voice_platform_voice_roster_ws_observation_enabled 1
''')
        self.assertEqual(values['voice_platform_voice_roster_ws_subscribers'],3)
        self.assertEqual(values['voice_platform_voice_roster_ws_initial_total.outcome.success'],2)
        self.assertEqual(values['voice_platform_voice_roster_ws_delivery_total.outcome.unavailable'],1)
        self.assertEqual(values['voice_platform_voice_roster_ws_refresh_total.outcome.failure'],1)
        self.assertEqual(values['voice_platform_voice_roster_ws_last_success_timestamp_seconds'],123)
        self.assertNotIn('voice_platform_voice_roster_ws_delivery_total.outcome.private_identifier',values)
