"""Include browser request-contract regressions in the project Python CI gate."""
import subprocess
import unittest
from pathlib import Path


class RequestContract(unittest.TestCase):
    def test_node_request_regressions(self):
        result=subprocess.run(['node','--test',str(Path(__file__).with_name('request.test.mjs'))],capture_output=True,text=True,timeout=20)
        self.assertEqual(result.returncode,0,result.stdout+result.stderr)
