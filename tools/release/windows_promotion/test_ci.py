"""Historical PASS and a run for another candidate cannot authorize a review PR."""
import copy
import json
import unittest
from subprocess import CompletedProcess
from unittest.mock import Mock
from tools.release.client_updates.candidate_ci import dispatch_and_wait
from .ci_proof import validate


class ProofTests(unittest.TestCase):
    def test_old_success_is_not_the_newly_dispatched_run(self):
        branch='codex/windows-catalog-windows-v1.0.39-123';sha='a'*40
        old=[{'databaseId':8,'headSha':sha,'headBranch':branch,'event':'workflow_dispatch'}]
        command=Mock(side_effect=[CompletedProcess([],0,json.dumps(old)),CompletedProcess([],0),CompletedProcess([],0,json.dumps(old))])
        with self.assertRaisesRegex(RuntimeError,'No CI run'):dispatch_and_wait(branch,sha,'Egkurilov/BOOHTACORD',
            command=command,fresh=True,registration_attempts=1,sleep=lambda _:None)

    def test_run_attempt_source_and_required_job_are_mandatory(self):
        run={'id':8,'run_attempt':2,'path':'.github/workflows/ci.yaml','event':'workflow_dispatch','head_sha':'a'*40,
          'head_branch':'codex/windows-catalog-fixture','status':'completed','conclusion':'success',
          'repository':{'full_name':'Egkurilov/BOOHTACORD'},'head_repository':{'full_name':'Egkurilov/BOOHTACORD'}}
        jobs=[{'name':'ci-required','status':'completed','conclusion':'success'}]
        validate(run,jobs,run['head_branch'],'a'*40,8,2)
        for change in ('sha','attempt','skip','foreign'):
            r=copy.deepcopy(run);j=copy.deepcopy(jobs)
            if change=='sha':r['head_sha']='b'*40
            if change=='attempt':r['run_attempt']=3
            if change=='skip':j[0]['conclusion']='skipped'
            if change=='foreign':r['head_repository']['full_name']='foreign/repo'
            with self.subTest(change=change),self.assertRaises(ValueError):validate(r,j,run['head_branch'],'a'*40,8,2)
