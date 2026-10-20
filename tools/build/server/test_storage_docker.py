"""Docker failures expose only finite operation/reason, never command details."""
import subprocess
import unittest
from unittest.mock import patch

from .storage_docker import Docker, DockerCommandError


class DockerCommandTests(unittest.TestCase):
    def test_timeout_has_finite_operation_without_private_argv_or_output(self):
        private = 'private-command-output-canary'
        failure = subprocess.TimeoutExpired(['docker', private], 30, output=private, stderr=private)
        with patch('subprocess.run', side_effect=failure):
            with self.assertRaises(DockerCommandError) as raised:
                Docker({}).command('info', '--format', private)
        self.assertEqual('daemon_info', raised.exception.operation)
        self.assertEqual('timeout', raised.exception.reason)
        self.assertNotIn(private, str(raised.exception))
        self.assertTrue(raised.exception.__suppress_context__)

    def test_command_exit_output_limit_encoding_and_os_errors_stay_finite(self):
        def bad_exit(*_, **kwargs):
            kwargs['stderr'].write(b'private-stderr-canary')
            return subprocess.CompletedProcess([], 1)
        def oversized(*_, **kwargs):
            kwargs['stdout'].write(b'x' * 1_000_001)
            return subprocess.CompletedProcess([], 0)
        def invalid_utf8(*_, **kwargs):
            kwargs['stdout'].write(b'\xff')
            return subprocess.CompletedProcess([], 0)
        for behavior, reason in ((bad_exit, 'exit_status'), (oversized, 'output_limit'),
                                 (invalid_utf8, 'encoding'), (OSError('private-path-canary'), 'os_error')):
            with self.subTest(reason=reason), patch('subprocess.run', side_effect=behavior):
                with self.assertRaises(DockerCommandError) as raised:
                    Docker({}).command('image', 'ls')
                self.assertEqual(('image_list', reason),
                                 (raised.exception.operation, raised.exception.reason))
                self.assertNotIn('canary', str(raised.exception))

    def test_unrecognized_operation_never_echoes_arguments(self):
        with patch('subprocess.run', side_effect=OSError('private-error-canary')):
            with self.assertRaisesRegex(DockerCommandError, '^Builder Docker resource_command: os_error$'):
                Docker({}).command('private-operation-canary', 'private-argument-canary')

    def test_success_preserves_bounded_decoded_stdout(self):
        def success(*_, **kwargs):
            kwargs['stdout'].write(b'  verified-output\n')
            return subprocess.CompletedProcess([], 0)
        with patch('subprocess.run', side_effect=success):
            self.assertEqual('verified-output', Docker({}).command('info'))
