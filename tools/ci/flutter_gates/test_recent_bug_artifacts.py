"""Retain the finite new bug-regression captures without opening arbitrary uploads."""
import unittest
from .artifacts import VISUALS
from tools.ci.artifact_policy.capture_inventory import complete


class RecentBugCaptureTests(unittest.TestCase):
    def test_reviewed_regression_images_are_required_and_unknown_images_rejected(self):
        required = {
            f'admin-search-{scale}-{inset}.png'
            for scale in (1.0, 1.3, 2.0) for inset in (0.0, 300.0)
        } | {'search-scope-48dp.png', 'revoked-image-pending-false.png',
             'revoked-image-pending-true.png'}
        self.assertTrue(required <= set(VISUALS))
        complete('flutter', dict.fromkeys(VISUALS))
        for name in required:
            with self.subTest(missing=name), self.assertRaises(ValueError):
                complete('flutter', dict.fromkeys(set(VISUALS) - {name}))
        with self.assertRaises(ValueError):
            complete('flutter', dict.fromkeys((*VISUALS, 'revoked-image-user-upload.png')))


if __name__ == '__main__':
    unittest.main()
