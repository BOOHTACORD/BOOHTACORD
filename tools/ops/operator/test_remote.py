import unittest
from unittest.mock import patch
from . import remote


class ForcedReadOnlyTests(unittest.TestCase):
    def test_exact_source_checked_before_and_after_read_only_diagnostic(self):
        with patch.object(remote,'invoke',side_effect=[('a'*40+'\n').encode(),b'private observation',('a'*40+'\n').encode()]) as invoke:
            self.assertEqual('boohtacord-operator-v1 PASS '+'a'*40+'\n',remote.observe('audit','a'*40,None))
            self.assertEqual(3,invoke.call_count)

    def test_source_drift_cannot_pass_and_read_only_entry_never_accepts_shell(self):
        with patch.object(remote,'invoke',return_value=('b'*40+'\n').encode()) as invoke:
            with self.assertRaises(ValueError):remote.observe('audit','a'*40,None)
            self.assertEqual(1,invoke.call_count)
