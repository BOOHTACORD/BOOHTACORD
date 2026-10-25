import unittest
from .warning_policy import PREFIX, validate


class KotlinWarningTests(unittest.TestCase):
    def test_legacy_pinned_firebase_core_and_both_clean_builds_are_accepted(self):
        for mode in ('legacy', 'builtin'):
            validate(mode, PREFIX + ' firebase_core\n')
            validate(mode, 'Build successful\n')

    def test_unreviewed_plugin_is_rejected_in_both_modes(self):
        for mode, suffix in (('builtin', ' other'), ('legacy', ' other'),
                             ('legacy', ' firebase_core, other')):
            with self.subTest(mode=mode, suffix=suffix), self.assertRaises(ValueError):
                validate(mode, PREFIX + suffix)
        with self.assertRaises(ValueError):
            validate('unknown', '')
