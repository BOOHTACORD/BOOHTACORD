"""Acceptance cleanup must never close a pre-existing user installation."""
import hashlib
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from . import windows_journey


class Fixture:
    def __init__(self, root):
        self.root = root


class JourneyOwnershipTests(unittest.TestCase):
    def test_preexisting_installation_is_refused_without_closing_its_process(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            baseline = root / '.out/issue337-windows-packages/78'
            baseline.mkdir(parents=True)
            installer = baseline / 'FixtureSetup.exe'
            installer.write_bytes(b'synthetic installer; never executed')
            source = '1' * 40
            (baseline / 'qa-identity.json').write_text(json.dumps({
                'source': source, 'files': {installer.name: {
                    'sha256': hashlib.sha256(installer.read_bytes()).hexdigest()}}}))
            local = root / 'local'
            executable = local / 'QA337 Приложение/BOOHTACORD/current/boohtacord_desktop.exe'
            executable.parent.mkdir(parents=True)
            executable.write_bytes(b'pre-existing user installation')
            with patch.object(windows_journey, 'ROOT', root), \
                    patch.object(windows_journey, 'Stack', Fixture), \
                    patch.object(windows_journey, 'wait_envelope', return_value={}), \
                    patch.object(windows_journey, 'running_at', return_value=[337]), \
                    patch.object(windows_journey, 'close_owned') as close, \
                    patch.dict('os.environ', {'RUNNER_TEMP': str(root / 'temp'),
                                             'APPDATA': str(root / 'appdata'),
                                             'LOCALAPPDATA': str(local)}):
                with self.assertRaisesRegex(RuntimeError, 'Refusing an existing'):
                    windows_journey.run(source, 1)
                close.assert_not_called()
                self.assertEqual(executable.read_bytes(), b'pre-existing user installation')
