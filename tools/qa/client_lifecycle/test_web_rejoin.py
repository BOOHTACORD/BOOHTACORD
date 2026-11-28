"""Run dependency-free discovery safety regressions in the normal Contracts gate."""
from pathlib import Path
import shutil
import subprocess
import unittest


class WebRejoinSafetyTests(unittest.TestCase):
    def test_owned_discovery_fault_boundaries(self):
        root = Path(__file__).resolve().parents[3]
        node = shutil.which('node')
        self.assertIsNotNone(node, 'Pinned Node is required for Web rejoin safety checks')
        leaf = 'tools/qa/client_lifecycle/web_rejoin/'
        result = subprocess.run([node, '--test', leaf+'port.test.mjs', leaf+'discovery.test.mjs'],
                                cwd=root, capture_output=True, text=True, encoding='utf-8', timeout=20)
        self.assertEqual(result.returncode, 0, result.stdout+result.stderr)
