import unittest
from unittest.mock import patch
from . import plan


class SDKPlanTests(unittest.TestCase):
    def test_default_candidate_does_not_probe_or_publish_a_release(self):
        with patch.object(plan.execution,'context',return_value={}),patch.object(plan,'absent') as absent:
            self.assertFalse(plan.prepare('false')['publish_requested']);absent.assert_not_called()

    def test_existing_version_or_non_master_stops_before_expensive_build(self):
        with patch.object(plan.execution,'context',return_value={}),patch.dict('os.environ',{'GITHUB_REF':'refs/heads/master'}),patch.object(plan,'absent',return_value=False):
            with self.assertRaises(ValueError):plan.prepare('true')
        with patch.object(plan.execution,'context',return_value={}),patch.dict('os.environ',{'GITHUB_REF':'refs/heads/feature'}),patch.object(plan,'absent') as absent:
            with self.assertRaises(ValueError):plan.prepare('true')
            absent.assert_not_called()
