"""Missing/NOT_RUN/blocked evidence or a caller's unverified GO cannot close migration."""
import unittest
from .readiness import evaluate


class ReadinessTests(unittest.TestCase):
    def test_absent_or_unexecuted_acceptance_is_no_go(self):
        for value in ({},{'control-matrix':{'status':'NOT_RUN'}},{'control-matrix':{'status':'BLOCKED'}}):
            row=evaluate('a'*40,value,None)
            self.assertEqual('NO-GO',row['decision']);self.assertTrue(row['outstanding'])

    def test_fabricated_owner_flag_or_focused_simulation_cannot_be_actual_acceptance(self):
        row=evaluate('a'*40,{'control-matrix':dict(status='PASS',scope='focused',source_revision='a'*40)}, {'verified':False})
        self.assertEqual('NO-GO',row['decision'])

    def test_all_verified_scopes_still_need_authenticated_owner_review(self):
        from .readiness import policy,VerifiedReceipt,VerifiedApproval
        records={key:VerifiedReceipt(key,'a'*40,scope,'b'*64) for key,scope in policy()['criteria'].items()}
        self.assertEqual('NO-GO',evaluate('a'*40,records,None)['decision'])
        self.assertEqual('NO-GO',evaluate('a'*40,records,{'verified':True,'reviewer_ids':[43]})['decision'])
        self.assertEqual('GO',evaluate('a'*40,records,VerifiedApproval('a'*40,(43,),'101'))['decision'])
        records.pop('server-release');self.assertEqual('NO-GO',evaluate('a'*40,records,VerifiedApproval('a'*40,(43,),'101'))['decision'])
