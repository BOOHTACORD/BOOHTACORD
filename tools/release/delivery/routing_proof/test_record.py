import copy
import json
import unittest
from .record import record


class RouteProofTests(unittest.TestCase):
    def setUp(self):
        self.run={'id':123,'run_attempt':2,'head_sha':'a'*40,'head_repository':{'full_name':'owner/repo'},
            'path':'.github/workflows/build-server.yaml','head_branch':'master','event':'push',
            'status':'completed','conclusion':'success'}
        self.result={'revision':'a'*40,'run_id':123,'has_bundle':False,'format_version':2}
        self.env={'GITHUB_REPOSITORY':'owner/repo','GITHUB_SHA':'b'*40,'GITHUB_EVENT_NAME':'workflow_run',
            'GITHUB_RUN_ID':'456','GITHUB_RUN_ATTEMPT':'2','GITHUB_TOKEN':'private-never-copy'}

    def test_public_record_binds_both_runs_without_copying_credentials(self):
        value=record(self.run,self.result,self.env)
        self.assertEqual(value['controller'],{'run_id':456,'run_attempt':2,'revision':'b'*40,'event':'workflow_run'})
        self.assertEqual(value['producer']['source_revision'],'a'*40)
        self.assertEqual(value['producer']['run_attempt'],2)
        self.assertIs(value['server_release_impact'],False)
        self.assertNotIn('private-never-copy',json.dumps(value))
        self.result['has_bundle']=True
        self.assertIs(record(self.run,self.result,self.env)['server_release_impact'],True)
        self.result['format_version']=1
        self.assertIsNone(record(self.run,self.result,self.env)['server_release_impact'])

    def test_invalid_controller_or_detached_producer_cannot_publish_route(self):
        for name,value in [('GITHUB_RUN_ID','0'),('GITHUB_RUN_ID','00456'),('GITHUB_RUN_ATTEMPT','-1'),
            ('GITHUB_SHA','invalid'),('GITHUB_EVENT_NAME','pull_request')]:
            env={**self.env,name:value}
            with self.subTest(name=name,value=value),self.assertRaises(ValueError):record(self.run,self.result,env)
        for key,value in [('revision','f'*40),('run_id',999),('has_bundle','false'),('format_version',3),('format_version',True)]:
            result={**self.result,key:value}
            with self.subTest(key=key),self.assertRaises(ValueError):record(self.run,result,self.env)
        for value in (None,True,0):
            run={**self.run,'run_attempt':value}
            with self.subTest(attempt=value),self.assertRaises(ValueError):record(run,self.result,self.env)
