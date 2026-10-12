"""Guard resource ownership before any native or service mutation."""
import unittest
from unittest.mock import patch
from . import policy

class PolicyTests(unittest.TestCase):
    def test_only_assigned_ios_uuid(self):
        with patch.object(policy, 'verify_device') as verify:
            with self.assertRaises(ValueError): policy.assigned_device('ios','82C26E13-0F1F-43F9-AF27-866DC22C2456')
            verify.assert_not_called()
            policy.assigned_device('ios',policy.IOS)
            verify.assert_called_once_with('ios',policy.IOS)
    def test_only_assigned_android_avd(self):
        with patch.object(policy.subprocess,'check_output',return_value='BOOHTACORD_QA_API35\nOK\n') as output, patch.object(policy,'verify_device') as verify:
            with self.assertRaises(ValueError): policy.assigned_device('android','emulator-5556')
            output.assert_not_called()
            policy.assigned_device('android','emulator-5554')
            verify.assert_called_once()
        with patch.object(policy.subprocess,'check_output',return_value='OTHER\n'):
            with self.assertRaises(ValueError):policy.assigned_device('android','emulator-5554')
    def test_cleanup_attempts_all_resources_and_retains_failures(self):
        records=[('network','n'),('container','a'),('container','b')]
        calls=[]
        def remove(name,owner,kind):
            calls.append(name)
            if name=='a':raise OSError('sanitized')
        with patch.object(policy,'remove_owned',side_effect=remove):
            errors=policy.cleanup_resources(records,'qa295298-owned')
        self.assertEqual(calls,['b','a','n'])
        self.assertEqual(records,[('container','a')])
        self.assertEqual(errors,[{'kind':'container','error_type':'OSError'}])
    def test_foreign_owner_rejected_before_removal(self):
        with patch.object(policy,'remove_owned') as remove:
            with self.assertRaises(ValueError):policy.cleanup_resources([('container','x')],'foreign')
            remove.assert_not_called()
