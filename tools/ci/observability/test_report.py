import unittest
from .report import analyze


class ObservationReportTests(unittest.TestCase):
    def test_thirty_sources_do_not_turn_reruns_into_confirmed_flakes(self):
        rows=[dict(id=i+1,status='completed',event='pull_request',conclusion='cancelled',head_sha='a'*40,
                   path='.github/workflows/ci.yaml',run_attempt=2,jobs=[]) for i in range(30)]
        value=analyze({'ci_pr':rows});self.assertEqual(30,value['sample_count']);self.assertIsNone(value['confirmed_flake_rate'])
        self.assertEqual(30,value['cohorts']['ci_pr']['cancelled_count'])
        with self.assertRaises(ValueError):analyze({'ci_pr':rows[:29]})
