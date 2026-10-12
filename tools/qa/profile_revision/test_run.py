import json
import tempfile
import unittest
from pathlib import Path
from tools.qa.profile_revision import run

class ProfileRunTests(unittest.TestCase):
    def test_new_attempt_never_keeps_old_pass(self):
        with tempfile.TemporaryDirectory() as work:
            output=Path(work)
            (output/'runtime.json').write_text('{"status":"PASS"}')
            (output/'scenario.json').write_text('{"status":"PASS"}')
            run.prepare_attempt(output)
            self.assertEqual(json.loads((output/'runtime.json').read_text())['status'],'RUNNING')
            self.assertFalse((output/'scenario.json').exists())

    def test_missing_or_failed_scenario_cannot_be_accepted(self):
        for scenario in [None, {}, {'status':'FAIL'}, {'status':'RUNNING'}]:
            with self.subTest(scenario=scenario):
                self.assertFalse(run.scenario_passed(scenario))
        self.assertTrue(run.scenario_passed({'status':'PASS'}))

if __name__=='__main__': unittest.main()
