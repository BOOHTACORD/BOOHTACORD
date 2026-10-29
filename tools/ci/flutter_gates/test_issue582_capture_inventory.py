"""Issue582 captures are mandatory synthetic scenarios, never a filename wildcard."""
import unittest
from tools.ci.artifact_policy import capture_inventory
from . import artifacts

EXPECTED = {'issue582-android-landscape-ime.png', 'issue582-iOS-landscape-ime.png'}


class Issue582CaptureInventoryTests(unittest.TestCase):
    def test_both_reviewed_producer_names_are_required(self):
        self.assertTrue(EXPECTED <= set(artifacts.VISUALS))
        capture_inventory.complete('flutter', dict.fromkeys(artifacts.VISUALS))
        for name in EXPECTED:
            with self.subTest(missing=name), self.assertRaises(ValueError):
                capture_inventory.complete('flutter', dict.fromkeys(
                    item for item in artifacts.VISUALS if item != name))

    def test_unreviewed_platform_alias_and_private_extras_are_rejected(self):
        for name in ('issue582-windows-landscape-ime.png',
                     'issue582-ios-landscape-ime.png',
                     'issue582-android-private.png'):
            with self.subTest(extra=name), self.assertRaises(ValueError):
                capture_inventory.complete(
                    'flutter', dict.fromkeys((*artifacts.VISUALS, name)))
