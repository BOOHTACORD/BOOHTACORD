import unittest

from tools.product_map.projection.status import source_status


class SourceStatusTests(unittest.TestCase):
    def test_revision_comparison_and_missing(self):
        self.assertEqual(source_status('SUPPORTED', 'IMPLEMENTED', 3, 2), 'BEHIND')
        self.assertEqual(source_status('SUPPORTED', 'IMPLEMENTED', 3, 3), 'IN_SYNC')
        self.assertEqual(source_status('SUPPORTED', 'IMPLEMENTED', 3, 4), 'AHEAD_UNREVIEWED')
        self.assertEqual(source_status('SUPPORTED', 'NOT_STARTED', 3, None), 'MISSING')

    def test_unknown_never_turns_green(self):
        self.assertEqual(source_status('SUPPORTED', 'UNKNOWN', 3, 3), 'UNKNOWN')
        self.assertEqual(source_status('UNKNOWN', 'IMPLEMENTED', 3, 3), 'UNKNOWN')
        self.assertEqual(source_status('SUPPORTED', 'IMPLEMENTED', None, 3), 'UNKNOWN')
        self.assertEqual(source_status('NOT_APPLICABLE', 'UNKNOWN', None, None), 'UNKNOWN')
        self.assertEqual(source_status('NOT_APPLICABLE', 'UNKNOWN', None, None,
                                       exception_approved=True), 'NOT_APPLICABLE')
        self.assertEqual(source_status('PLATFORM_EXCEPTION', 'UNKNOWN', None, None), 'UNKNOWN')
        self.assertEqual(source_status('PLATFORM_EXCEPTION', 'UNKNOWN', None, None,
                                       exception_approved=True), 'INTENTIONAL_DIFFERENCE')
