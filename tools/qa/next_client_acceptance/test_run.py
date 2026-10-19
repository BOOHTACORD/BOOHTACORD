"""Controller failures expose a finite stage, never subprocess text or inputs."""
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch
from . import run as controller


class ControllerFailureTests(unittest.TestCase):
    def test_build_stack_and_browser_failures_retain_only_finite_diagnostics(self):
        for phase in ('production-client-build', 'capacity-stack-start', 'browser-scenario'):
            with tempfile.TemporaryDirectory() as temporary, self.subTest(phase=phase):
                root = Path(temporary)
                error = subprocess.CalledProcessError(1, ['secret-password'], stderr='private-message-body')
                with patch.object(controller, 'ROOT', root, create=True), patch.object(controller, 'run') as run, \
                     patch.object(controller, 'Stack') as stack:
                    if phase == 'production-client-build': run.side_effect = error
                    if phase == 'capacity-stack-start': stack.return_value.start.side_effect = error
                    if phase == 'browser-scenario':
                        stack.return_value.password = 'secret-password'
                        stack.return_value.owner = 'private-resource-id'
                        run.side_effect = [None, error]
                    with self.assertRaises(subprocess.CalledProcessError): controller.main()
                path = root / '.out/next-client-acceptance/controller-failure.json'
                self.assertTrue(path.is_file())
                row = json.loads(path.read_text())
                self.assertEqual(row['stage'], phase)
                self.assertEqual(row['status'], 'FAIL')
                self.assertEqual(row['failure_type'], 'CalledProcessError')
                self.assertNotIn('secret-password', path.read_text())
                self.assertNotIn('private-message-body', path.read_text())
                self.assertNotIn('private-resource-id', path.read_text())

