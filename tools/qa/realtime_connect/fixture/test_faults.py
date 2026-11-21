"""Keep actual stdlib Go fault regressions in the project-owned CI Python suite."""
import os
from pathlib import Path
import subprocess
import unittest


class FaultRegressionTest(unittest.TestCase):
    def test_actual_go_admission_cancellation_and_unmodified_stream(self):
        subprocess.run(['go', 'test', './...'],
            cwd=Path(__file__).resolve().parents[1]/'faults',
            env=dict(os.environ, GO111MODULE='off'), check=True, timeout=60,
            stdout=subprocess.PIPE, stderr=subprocess.STDOUT)

    def test_web_diagnostics_never_retain_private_error_fields(self):
        subprocess.run(['node', '--test', 'failure.test.mjs'],
            cwd=Path(__file__).resolve().parents[1]/'web',
            check=True, timeout=30, stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT)
