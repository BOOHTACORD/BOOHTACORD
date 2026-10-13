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

    def test_output_name_keeps_runs_inside_owned_out_directory(self):
        self.assertEqual(policy.output_name('qa329332-20261013'),'qa329332-20261013')
        for value in ('../outside','/tmp/foreign','qa329332-password','qa329332-20261013/other'):
            with self.assertRaises(ValueError):policy.output_name(value)

    def test_backend_archive_adapter_rewrites_only_exact_owned_build_context(self):
        args=('docker','build','--file','/repo/backend/Dockerfile','/repo/backend')
        self.assertEqual(policy.backend_arguments(args,'/repo/backend','/own/backend'),('docker','build','--file','/own/backend/Dockerfile','/own/backend'))
        self.assertEqual(policy.backend_arguments(('docker','ps'),'/repo/backend','/own/backend'),('docker','ps'))
        with self.assertRaises(ValueError):policy.backend_arguments(('docker','build','--file','/foreign/Dockerfile','/repo/backend'),'/repo/backend','/own/backend')

    def test_receiver_review_budget_is_bounded_and_does_not_change_sender_fault_budget(self):
        self.assertEqual(policy.observation_poll_count(False),720)
        self.assertEqual(policy.observation_poll_count(True),1200)
        with self.assertRaises(ValueError):policy.observation_poll_count('unbounded')
