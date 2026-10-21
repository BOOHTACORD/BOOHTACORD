"""The remote shell wrapper reports only finite setup-failure phases."""
import os
from pathlib import Path
import subprocess
import unittest

from tools.release.install.diagnostics import failure_response, validate_response


SCRIPT = Path(__file__).with_name('install_received.sh')


class ReceivedInstallScriptTests(unittest.TestCase):
    def invoke(self, *arguments):
        return subprocess.run(['bash', str(SCRIPT), *arguments], capture_output=True, check=False,
                              env={**os.environ, 'SUDO_UID': str(os.getuid())})

    def test_invalid_revision_returns_only_a_bounded_safe_response(self):
        result = self.invoke('bad', 'b' * 64, 'c' * 64, 'd' * 40, 'e' * 40, 'f' * 32)
        self.assertEqual(0, result.returncode)
        self.assertEqual(b'', result.stderr)
        self.assertEqual(failure_response('remote_arguments'), validate_response(result.stdout))

    def test_missing_arguments_return_a_safe_failure_instead_of_an_unbound_shell_error(self):
        result = self.invoke('only-one-argument')
        self.assertEqual(0, result.returncode)
        self.assertEqual(b'', result.stderr)
        self.assertEqual(failure_response('remote_arguments'), validate_response(result.stdout))

    def test_missing_private_stage_is_classified_without_running_an_installer(self):
        result = self.invoke('a' * 40, 'b' * 64, 'c' * 64, 'd' * 40, 'e' * 40, 'f' * 32)
        self.assertEqual(0, result.returncode)
        self.assertEqual(b'', result.stderr)
        self.assertEqual(failure_response('remote_stage'), validate_response(result.stdout))


if __name__ == '__main__':
    unittest.main()
