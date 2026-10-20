"""One full functional pair must not become a statistical or release claim."""
import copy
import json
import os
from pathlib import Path
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch
from .results import OPERATIONS, PROFILES
from . import shadow_compare, shadow_legacy
from tools.ci.native import backend
from . import run as runner

SOURCE='a'*40
IDENTITY={'run_id':'123','run_attempt':'1'}


def fixture():
    run={'id':123,'run_attempt':1,'head_sha':SOURCE,'head_branch':'master',
         'event':'workflow_dispatch','path':'.github/workflows/backend-ci-shadow.yaml',
         'repository':{'full_name':'Egkurilov/BOOHTACORD'},
         'head_repository':{'full_name':'Egkurilov/BOOHTACORD'}}
    def time(seconds):
        return f'2026-10-20T00:{seconds//60:02}:{seconds%60:02}Z'
    rows=[]
    for index,(name,start,end) in enumerate((('legacy',0,1000),('profiles / static',0,50),
            ('profiles / database',0,100),('profiles / load',0,200),('profiles / backend',200,210),('compare',210,220))):
        rows.append(dict(id=index+1,name=name,run_id=123,run_attempt=1,head_sha=SOURCE,
            status='completed',conclusion='success',created_at=time(0),started_at=time(start),
            completed_at=time(end),labels=['ubuntu-24.04'],runner_group_name='GitHub Actions',runner_id=index+1))
    parts=[dict(source_revision=SOURCE,profile=n,status='PASS',operations=list(OPERATIONS[n]),
                seconds={'static':40,'database':90,'load':190}[n],execution=IDENTITY) for n in PROFILES]
    fanin=dict(source_revision=SOURCE,status='PASS',execution=IDENTITY,
               observed_profile_seconds={r['profile']:r['seconds'] for r in parts},checked_operations=11)
    legacy=dict(schema_version=1,source_revision=SOURCE,status='PASS',execution=IDENTITY,
                operations=list(shadow_compare.LEGACY_OPERATIONS),seconds=900,
                coverage_reference_revision=shadow_compare.REFERENCE_REVISION)
    return run,{'total_count':len(rows),'jobs':rows},{'legacy':{'result':'success'},'profiles':{'result':'success'}},legacy,parts,fanin


class ComparisonTests(unittest.TestCase):
    def test_complete_actual_pair_preserves_coverage_and_reports_n1_without_speed_claim(self):
        value=shadow_compare.compare(*fixture())
        self.assertEqual(value['status'],'PASS')
        self.assertTrue(value['coverage_not_reduced'])
        self.assertTrue(value['old_new_equivalent'])
        self.assertEqual(value['samples_per_arm'],1)
        self.assertFalse(value['performance_gain_asserted'])
        self.assertEqual(value['measurements']['profiles']['critical_seconds'],210)

    def test_foreign_incomplete_skipped_or_reduced_inputs_fail(self):
        for mutation in ('source','attempt','coverage','reference','part','fanin','failure','skip','runner','duration',
                         'nan','event','repository','extra','early-fan-in','shared-runner','missing-job','bool-attempt'):
            run,jobs,needs,old,parts,new=copy.deepcopy(fixture())
            if mutation=='source':old['source_revision']='b'*40
            if mutation=='attempt':parts[0]['execution']['run_attempt']='2'
            if mutation=='coverage':old['operations'].pop()
            if mutation=='reference':old['coverage_reference_revision']='b'*40
            if mutation=='part':parts.pop()
            if mutation=='fanin':new['checked_operations']=10
            if mutation=='failure':needs['legacy']['result']='failure'
            if mutation=='skip':jobs['jobs'][1]['conclusion']='skipped'
            if mutation=='runner':jobs['jobs'][1]['labels']=['self-hosted']
            if mutation=='duration':old['seconds']=True
            if mutation=='nan':parts[0]['seconds']=float('nan')
            if mutation=='event':run['event']='pull_request'
            if mutation=='repository':run['head_repository']['full_name']='foreign/repo'
            if mutation=='extra':new['private']='controlled-fixture'
            if mutation=='early-fan-in':jobs['jobs'][4]['started_at']=jobs['jobs'][3]['started_at']
            if mutation=='shared-runner':jobs['jobs'][1]['runner_id']=jobs['jobs'][2]['runner_id']
            if mutation=='missing-job':jobs['jobs'].pop()
            if mutation=='bool-attempt':run['run_attempt']=True
            with self.subTest(mutation=mutation),self.assertRaises(ValueError):
                shadow_compare.compare(run,jobs,needs,old,parts,new)


class SequentialRunnerTests(unittest.TestCase):
    def test_full_original_command_coverage_runs_in_order_without_test_result_cache(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp);calls=[]
            def record(*args,**kwargs):
                calls.append(args);return SimpleNamespace(returncode=0)
            with patch.object(shadow_legacy,'ROOT',root),patch.object(backend,'ROOT',root), \
                 patch.object(shadow_legacy,'checked_source',return_value=SOURCE), \
                 patch.object(backend,'output',return_value='go version go1.26.4 linux/amd64'), \
                 patch.object(backend,'run',side_effect=record),patch.object(runner,'run',side_effect=record), \
                 patch.dict(os.environ,GITHUB_ACTIONS='true',GITHUB_RUN_ID='123',GITHUB_RUN_ATTEMPT='1'):
                shadow_legacy.execute()
            row=json.loads((root/'.out/ci/backend-shadow-legacy.json').read_text())
            self.assertEqual(row['status'],'PASS');self.assertEqual(len(calls),11)
            self.assertEqual(calls[0],('go','run','./cmd/check-test-database'))
            self.assertEqual(calls[1],('go','test','-json','-count=1','./...'))
            self.assertIn('tools/verify/go_test_events/verify-go-test-events.py',calls[2])
            self.assertEqual(calls[3:5],[('go','vet','./...'),('go','build','./...')])
            self.assertEqual([c[c.index('--profile')+1] for c in calls[6:]],['normal','reconnect','uploads','nat_auth','faults'])

    def test_preflight_or_later_check_failure_invalidates_old_success(self):
        with tempfile.TemporaryDirectory() as tmp,patch.object(shadow_legacy,'ROOT',Path(tmp)), \
             patch.object(shadow_legacy,'checked_source',side_effect=RuntimeError('controlled-source-failure')):
            path=Path(tmp)/'.out/ci/backend-shadow-legacy.json';path.parent.mkdir(parents=True)
            path.write_text('{"status":"PASS"}')
            with self.assertRaises(RuntimeError):shadow_legacy.execute()
            self.assertEqual(json.loads(path.read_text())['status'],'FAIL')
