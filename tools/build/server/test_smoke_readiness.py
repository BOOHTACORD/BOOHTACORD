import tempfile
import unittest
from pathlib import Path
import subprocess
from unittest.mock import patch
from .smoke import wait_database
from .inputs import source_root


class SmokeReadinessTests(unittest.TestCase):
    def test_temporary_unix_readiness_cannot_complete_tcp_gate(self):
        probes = []
        def readiness(command, **kwargs):
            probes.append(command)
            # The init server accepts Unix sockets immediately; TCP comes later.
            code = (1 if len(probes) == 1 else 0) if '--host=127.0.0.1' in command else 0
            return subprocess.CompletedProcess(command, code)
        with patch('tools.build.server.smoke.subprocess.run', side_effect=readiness), patch('tools.build.server.smoke.time.sleep') as sleep:
            wait_database('owned-db')
        self.assertEqual(len(probes), 2)
        sleep.assert_called_once_with(1)

    def test_unavailable_tcp_exhausts_bounded_budget(self):
        with patch('tools.build.server.smoke.subprocess.run', return_value=subprocess.CompletedProcess([], 1)) as probe, patch('tools.build.server.smoke.time.sleep'):
            with self.assertRaises(RuntimeError): wait_database('owned-db', attempts=3)
        self.assertEqual(probe.call_count, 3)

    def test_explicit_source_is_exact_repository_root(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary).resolve()
            subprocess.run(['git', 'init', '-q', str(root)], check=True)
            (root / 'nested').mkdir()
            self.assertEqual(source_root(root), root)
            with self.assertRaises(ValueError): source_root(root / 'nested')

    def test_default_source_remains_the_builder_repository(self):
        self.assertEqual(source_root(None), Path(__file__).resolve().parents[3])
