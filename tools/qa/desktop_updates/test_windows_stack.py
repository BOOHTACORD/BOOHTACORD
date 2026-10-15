"""Startup diagnostics must remain bounded even when dependency logs are unsafe."""
import unittest

from .windows_stack import startup_failure


class StartupDiagnosticTests(unittest.TestCase):
    def test_reports_supported_role_and_exit_without_private_log_values(self):
        raw = b'filesystem space information is invalid password=PRIVATE token=SECRET C:\\Users\\private-user\\data'
        result = startup_failure('api', 1, raw)
        self.assertEqual(result, {'service': 'api', 'exit_code': 1, 'reason': 'invalid_space'})
        self.assertNotIn('PRIVATE', str(result))
        self.assertNotIn('private-user', str(result))

    def test_unknown_output_is_never_echoed(self):
        self.assertEqual(startup_failure('sfu', 2, b'arbitrary private output'),
                         {'service': 'sfu', 'exit_code': 2, 'reason': 'unclassified'})
        with self.assertRaises(ValueError):
            startup_failure('untrusted-service-name', 1, b'')
