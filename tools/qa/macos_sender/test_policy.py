import unittest
from unittest.mock import patch
from . import policy

class PolicyTests(unittest.TestCase):
    def test_assigned_ports_are_exact_and_exclude_held_stack(self):
        self.assertEqual(tuple(policy.PORTS.values()),(5060,5061,5062,5063,5064,5065))
        self.assertNotIn(4930,policy.PORTS.values())
    def test_namespace_is_owned_and_bounded(self):
        self.assertEqual(policy.namespace('0123456789abcdef'),'ru.boohtacord.localqa.qa98325.0123456789abcdef')
        for value in ('production','../foreign','a'*17):
            with self.assertRaises(ValueError):policy.namespace(value)
    def test_cleanup_continues_after_failure_and_rejects_foreign_owner(self):
        rows=[('container','qa98325-test-api'),('image','qa98325-test-api')]
        with patch.object(policy,'remove_owned',side_effect=[RuntimeError(),None]) as remove:
            errors=policy.cleanup(rows,'qa98325-0123456789abcdef')
            self.assertEqual(remove.call_count,2)
            self.assertEqual(len(errors),1)
            self.assertEqual(len(rows),1)
        with self.assertRaises(ValueError):policy.cleanup(rows,'qa-client-foreign')
