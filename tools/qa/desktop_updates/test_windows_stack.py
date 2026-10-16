"""Startup diagnostics must remain bounded even when dependency logs are unsafe."""
import unittest
from unittest.mock import patch

from .windows_stack import Stack, startup_failure


class CatalogReadinessTests(unittest.TestCase):
    def test_waits_until_actual_api_serves_the_exact_signed_catalog(self):
        stack = object.__new__(Stack)
        envelope = {'payload': 'selected', 'signature': 'owner'}
        replies = [
            (200, {'catalog_revision': 1, 'state': 'unconfigured', 'target': None}, {}),
            (200, {'catalog_revision': 2, 'state': 'published',
                   'target': {'install_artifact': envelope}}, {}),
        ]
        paths = []
        def request(path):
            paths.append(path)
            return replies.pop(0)
        stack.request = request
        with patch('tools.qa.desktop_updates.windows_stack.time.sleep'):
            stack.wait_catalog(envelope)
        self.assertEqual(len(paths), 2)
        self.assertTrue(all(path == '/client-updates?platform=windows&distribution=direct&channel=beta&arch=x64'
                            for path in paths))

    def test_never_starts_client_for_an_old_or_different_catalog(self):
        stack = object.__new__(Stack)
        stack.request = lambda _: (200, {'catalog_revision': 2, 'state': 'published',
                                        'target': {'install_artifact': {'payload': 'other'}}}, {})
        with patch('tools.qa.desktop_updates.windows_stack.time.monotonic', side_effect=[0, 1, 31]), \
                patch('tools.qa.desktop_updates.windows_stack.time.sleep'):
            with self.assertRaisesRegex(RuntimeError, 'signed catalog'):
                stack.wait_catalog({'payload': 'selected'})


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
