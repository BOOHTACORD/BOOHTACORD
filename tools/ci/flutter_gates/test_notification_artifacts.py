"""Publish the six synthetic notification settings captures and reject extras."""
import unittest
from .artifacts import VISUALS
from tools.ci.artifact_policy.capture_inventory import complete


class NotificationCaptureTests(unittest.TestCase):
    def test_settings_captures_are_complete_and_unknown_frames_stay_rejected(self):
        expected = {
            'notification-settings-393-1-top.png', 'notification-settings-393-1-bottom.png',
            'notification-settings-393-2-top.png', 'notification-settings-393-2-bottom.png',
            'notification-settings-1440-1-top.png', 'notification-settings-1440-1-bottom.png',
        }
        self.assertEqual(expected, {name for name in VISUALS if name.startswith('notification-')})
        complete('flutter', dict.fromkeys(VISUALS))
        for missing in expected:
            with self.subTest(missing=missing), self.assertRaises(ValueError):
                complete('flutter', dict.fromkeys(name for name in VISUALS if name != missing))
        with self.assertRaises(ValueError):
            complete('flutter', dict.fromkeys((*VISUALS, 'notification-private-upload.png')))
