"""A red gate stays red; a rerun/cancellation is not proof of a flaky test."""
import unittest
from .triage import classify,binding


class TriageTests(unittest.TestCase):
    def test_foreign_workflow_cannot_borrow_a_required_aggregate_reproduction(self):
        job=dict(id=12,name='native-required',conclusion='failure',steps=[dict(number=5,name='Require quality',conclusion='failure')])
        result=classify(dict(path='.github/workflows/foreign.yaml',conclusion='failure',status='completed'),[job])
        self.assertEqual(result['failures'][0]['component'],'unknown')
        self.assertNotIn('tools.ci.master_quality.run',result['failures'][0]['reproduce'])

    def test_pr_cancellation_does_not_become_a_master_defect(self):
        result=classify(dict(event='pull_request',conclusion='cancelled'),[])
        self.assertEqual('CANCELLED',result['outcome']);self.assertFalse(result['master_defect'])
        self.assertEqual('UNKNOWN',result['confirmed_flake'])

    def test_failed_assertion_signing_or_missing_evidence_never_qualifies_for_retry(self):
        for name in ('Run browser assertions','Build signed Android distribution','Retain source-bound evidence'):
            result=classify(dict(event='push',conclusion='failure'),[dict(name='windows / windows',conclusion='failure',steps=[dict(number=3,name=name,conclusion='failure')])])
            self.assertEqual('FAIL',result['outcome']);self.assertFalse(result['retry_test'])
            self.assertEqual(3,result['failures'][0]['step_number'])

    def test_pr_api_head_is_distinct_from_verified_test_merge_source(self):
        run=dict(id=101,head_sha='b'*40,run_attempt=1,event='pull_request',repository={'full_name':'BOOHTACORD/BOOHTACORD'})
        env=dict(GITHUB_RUN_ID='101',GITHUB_RUN_ATTEMPT='1',GITHUB_EVENT_NAME='pull_request',GITHUB_REF='refs/pull/2/merge')
        self.assertEqual('checked_pr_merge_parent',binding(run,env,'a'*40,['c'*40,'b'*40]))
        with self.assertRaises(ValueError):binding(run,env,'a'*40,['c'*40,'d'*40])
