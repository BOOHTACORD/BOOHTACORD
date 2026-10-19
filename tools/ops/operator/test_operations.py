import unittest
from unittest.mock import Mock
from .operations import perform,current


class CapabilityTests(unittest.TestCase):
    def test_diagnostic_rpc_is_fixed_and_needs_source_bound_result(self):
        ssh=Mock();ssh.command.return_value=b'private unqualified host observation'
        with self.assertRaises(ValueError):perform(dict(operation='audit',expected_source='a'*40,risk='read-only',timeout=30),ssh,None)
        ssh.command.assert_called_once_with('boohtacord-operator-v1 audit '+'a'*40,30)
        ssh.script.assert_not_called();ssh.copy.assert_not_called()

    def test_mutation_does_not_start_on_another_deployed_source(self):
        ssh=Mock();ssh.script.return_value=('b'*40+'\n').encode()
        with self.assertRaises(ValueError):perform(dict(operation='rollback',expected_source='a'*40,risk='mutation',timeout=30),ssh,None)
        ssh.command.assert_not_called();ssh.copy.assert_not_called()
