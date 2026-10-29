import unittest
from .test_support import API,execute


class ProvenanceBoundaryTests(unittest.TestCase):
    def rejected(self,api):
        trace,_,endpoints=execute(api)
        self.assertEqual(trace['status'],'FAIL')
        self.assertEqual(trace['failure_stage'],'deployment')
        self.assertEqual(endpoints,0)

    def test_route_and_master_quality_must_match_source_scope_and_current_attempt(self):
        cases=[('route',None,'schema_version',True),('quality',None,'schema_version',True),
            ('route',None,'status','FAIL'),('route',None,'repository','fork/repo'),
            ('route',None,'server_release_impact',True),('route',None,'server_release_impact','false'),
            ('route','controller','revision','f'*40),('route','controller','run_id',999),
            ('route','controller','run_attempt',1),('route','producer','run_id',True),
            ('route','producer','source_revision','f'*40),('route','producer','run_attempt',1),
            ('route','producer','has_bundle',True),('route','producer','format_version',1),
            ('quality',None,'status','FAIL'),('quality',None,'scope','native'),
            ('quality',None,'source_revision','f'*40),('quality',None,'run_id','999'),
            ('quality',None,'run_attempt','1'),('quality',None,'server_release_impact',True),
            ('quality',None,'server_release_impact','false'),('quality',None,'map_sha256','bad'),
            ('quality','jobs','backend','success')]
        for name,parent,key,value in cases:
            api=API();target=getattr(api,name);target=target[parent] if parent else target
            target[key]=value;api.refresh()
            with self.subTest(name=name,parent=parent,key=key,value=value):self.rejected(api)

    def test_foreign_running_or_other_workflow_runs_do_not_become_noops(self):
        for identity in (123,456):
            for key,value in [('head_branch','codex/foreign'),('path','.github/workflows/ci.yaml'),
                ('event','pull_request'),('status','in_progress'),('conclusion','failure'),
                ('run_attempt',3),('head_sha','f'*40),('repository',{'id':1,'full_name':'fork/repo'}),
                ('head_repository',{'id':1,'full_name':'fork/repo'})]:
                api=API();api.runs[identity][key]=value
                with self.subTest(identity=identity,key=key):self.rejected(api)

    def test_failed_ambiguous_missing_or_foreign_attempt_jobs_fail_closed(self):
        for identity in (123,456):
            for change in ('missing','duplicate','failed','foreign','attempt','running','duplicate-id'):
                api=API();rows=api.job_rows[identity]
                if change=='missing':rows.pop(0)
                if change=='duplicate':rows.append(dict(rows[0],id=999))
                if change=='failed':rows[0]['conclusion']='failure'
                if change=='foreign':rows[0]['run_id']=999
                if change=='attempt':rows[0]['run_attempt']=1
                if change=='running':rows[0]['status']='in_progress'
                if change=='duplicate-id':rows[0]['id']=rows[1]['id']
                with self.subTest(identity=identity,change=change):self.rejected(api)

    def test_missing_expired_foreign_tampered_or_wrong_attempt_artifacts_fail_closed(self):
        for identity in (123,456):
            for change in ('missing','duplicate','expired','hash','source','repository','head-repository','branch','owner','attempt'):
                api=API();rows=api.rows[identity];row=rows[0]
                if change=='missing':rows.clear()
                if change=='duplicate':rows.append(dict(row))
                if change=='expired':row['expired']=True
                if change=='hash':row['digest']='sha256:'+'0'*64
                if change=='source':row['workflow_run']['head_sha']='f'*40
                if change=='repository':row['workflow_run']['repository_id']=2
                if change=='head-repository':row['workflow_run']['head_repository_id']=2
                if change=='branch':row['workflow_run']['head_branch']='codex/foreign'
                if change=='owner':row['workflow_run']['id']=999
                if change=='attempt':row['name']=row['name'][:-1]+'1'
                with self.subTest(identity=identity,change=change):self.rejected(api)
