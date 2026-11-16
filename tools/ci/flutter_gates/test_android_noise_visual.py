"""The Android retry capture is required, not an unchecked extra artifact."""
import unittest

from tools.ci.artifact_policy.capture_inventory import complete
from .artifacts import VISUALS


class AndroidNoiseVisualTest(unittest.TestCase):
    def test_retry_capture_is_required(self):
        name = 'android-noise-retry-menu-390.png'
        self.assertIn(name, VISUALS)
        with self.assertRaises(ValueError):
            complete('flutter', dict.fromkeys(item for item in VISUALS if item != name))
