import unittest

from tools.qa.voice_roster_multiclient.outcome import classify


class OutcomeTest(unittest.TestCase):
    def test_requires_every_live_roster_step(self):
        checks = dict.fromkeys(('empty', 'first_join', 'second_join', 'microphone', 'audio_receiving', 'screen_share', 'screen_receiving', 'leave', 'rejoin', 'transfer', 'live_transport', 'ws_independent', 'socket_guard', 'public_privacy'), True)
        self.assertEqual(classify(checks, 0, True, True), 'SMOKE_PASS')
        for name in checks:
            missing = dict(checks, **{name: False})
            self.assertEqual(classify(missing, 0, True, True), 'FAIL')

    def test_fails_on_browser_error_source_change_or_failed_cleanup(self):
        checks = dict.fromkeys(('empty', 'first_join', 'second_join', 'microphone', 'audio_receiving', 'screen_share', 'screen_receiving', 'leave', 'rejoin', 'transfer', 'live_transport', 'ws_independent', 'socket_guard', 'public_privacy'), True)
        self.assertEqual(classify(checks, 1, True, True), 'FAIL')
        self.assertEqual(classify(checks, 0, False, True), 'FAIL')
        self.assertEqual(classify(checks, 0, True, False), 'FAIL')
        self.assertEqual(classify({}, 0, True, True), 'FAIL')


if __name__ == '__main__':
    unittest.main()
