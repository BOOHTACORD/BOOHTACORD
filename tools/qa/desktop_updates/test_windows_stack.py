"""Startup diagnostics must remain bounded even when dependency logs are unsafe."""
import unittest
import ipaddress
from unittest.mock import patch

from .windows_stack import (Stack, startup_failure, private_media_sfu_configuration,
                            owned_private_media_address)


class PrivateMediaConfigurationTests(unittest.TestCase):
    def test_advertised_address_must_bind_on_this_host_without_public_fallback(self):
        answers = [(None, None, None, None, (address, 0))
                   for address in ('8.8.8.8', '10.0.0.1', '10.0.0.2')]
        with patch('tools.qa.desktop_updates.windows_stack.socket.getaddrinfo', return_value=answers), \
                patch('tools.qa.desktop_updates.windows_stack.socket.socket') as factory:
            bind = factory.return_value.__enter__.return_value.bind
            bind.side_effect = [OSError('not local'), None]
            self.assertEqual(owned_private_media_address(), '10.0.0.2')
            self.assertEqual([call.args for call in bind.call_args_list],
                             [(('10.0.0.1', 0),), (('10.0.0.2', 0),)])
        with patch('tools.qa.desktop_updates.windows_stack.socket.getaddrinfo', return_value=[]):
            with self.assertRaisesRegex(RuntimeError, 'No owned RFC1918'):
                owned_private_media_address()

    def test_management_stays_loopback_while_media_uses_one_private_vm_interface(self):
        config = private_media_sfu_configuration('10.23.45.67')
        self.assertTrue(config['bind_addresses'])
        self.assertTrue(all(ipaddress.ip_address(value).is_loopback
                            for value in config['bind_addresses']))
        rtc = config['rtc']
        self.assertTrue(rtc['force_tcp'])
        self.assertEqual(rtc['udp_port'], 0)
        self.assertEqual(rtc['tcp_port'], 4914)
        self.assertFalse(rtc['use_external_ip'])
        self.assertFalse(rtc['enable_loopback_candidate'])
        self.assertEqual(rtc['ips']['includes'], ['10.23.45.67/32'])
        self.assertEqual(config['webhook']['urls'],
                         ['http://127.0.0.1:4911/internal/livekit/roster'])

    def test_never_advertises_public_loopback_link_local_or_wildcard_media(self):
        for address in ('8.8.8.8', '127.0.0.1', '0.0.0.0', '169.254.1.2',
                        '::1', 'fc00::1', '192.0.2.1', '10.0.0.1/8'):
            with self.subTest(address=address), self.assertRaises(ValueError):
                private_media_sfu_configuration(address)
        for address in ('10.0.0.5', '172.16.0.5', '192.168.0.5'):
            self.assertEqual(private_media_sfu_configuration(address)['rtc']['ips']['includes'],
                             [address + '/32'])


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
