import json
import tempfile
import unittest
from pathlib import Path
from . import run

class RequestedMatrixFreshnessTests(unittest.TestCase):
    def test_all_requested_widths_are_invalidated_before_first_stack_failure(self):
        with tempfile.TemporaryDirectory() as directory:
            base=Path(directory)
            for width in [393,1440]:
                (base/str(width)).mkdir();(base/str(width)/'runtime.json').write_text('{"status":"PASS"}')
            run.initialize_requested_widths(base,[393,1440],{'candidate':'new-source'})
            for width in [393,1440]:
                report=json.loads((base/str(width)/'runtime.json').read_text())
                self.assertEqual(report['status'],'NOT_RUN')
                self.assertEqual(report['candidate'],'new-source')
                self.assertEqual(report['reason'],'Requested matrix entry has not started')
            self.assertEqual(len(list((base/'previous-harness-runs').rglob('runtime.json'))),2)
