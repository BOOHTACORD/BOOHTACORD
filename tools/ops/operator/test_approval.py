import unittest
from .approval import validate
from .test_policy import context
from .policy import request


def run():return dict(id=101,head_sha='a'*40,run_attempt=1,event='workflow_dispatch',head_branch='master',
                      path='.github/workflows/rehearse-compatible-rollback.yaml',repository={'full_name':'Egkurilov/BOOHTACORD'},
                      head_repository={'full_name':'Egkurilov/BOOHTACORD'},actor={'id':42})


def plan():return request('rollback',context(PREVIOUS_SOURCE='c'*40,OBSERVERS_CONFIRMED='two-browsers-ready'))


class ApprovalTests(unittest.TestCase):
    def test_independent_authenticated_environment_review(self):
        self.assertEqual([43],validate(plan(),run(),[dict(state='approved',environments=[{'name':'production'}],user={'id':43})]))

    def test_missing_self_other_environment_rejected_or_stale_approval_cannot_pass(self):
        for rows in [[],[dict(state='approved',environments=[{'name':'other'}],user={'id':43})],
                     [dict(state='approved',environments=[{'name':'production'}],user={'id':42})],
                     [dict(state='rejected',environments=[{'name':'production'}],user={'id':43})]]:
            with self.subTest(rows=rows),self.assertRaises(ValueError):validate(plan(),run(),rows)
        changed=run();changed['run_attempt']=2
        with self.assertRaises(ValueError):validate(plan(),changed,[])
