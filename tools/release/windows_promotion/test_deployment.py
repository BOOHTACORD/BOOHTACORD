"""Archive ownership and successful exact-source deployment are separate from live catalog checks."""
import copy
from datetime import datetime,timezone,timedelta
import hashlib
import io
import json
from pathlib import Path
import unittest
from unittest.mock import patch
import zipfile
from tools.release.delivery.receipt import build
from tools.release.delivery.test_receipt import outcomes,result
from . import deployment,intent


def fixture():
    data=build(outcomes(),result());source=data['delivery']['source_revision']
    stamp=datetime.now(timezone.utc)-timedelta(days=2)
    data['delivery']['readback']['checked_at']=stamp.isoformat()
    data['producer']={'id':1,'name':f'server-{source}-123-1','size_in_bytes':100,'digest':'sha256:'+'b'*64,
        'source_revision':source,'run_id':123,'run_attempt':1,'format_version':2}
    run={'id':456,'run_attempt':1,'head_sha':'c'*40,'head_branch':'master','path':'.github/workflows/deploy-production.yaml',
        'event':'workflow_run','status':'completed','conclusion':'success','repository':{'full_name':intent.REPOSITORY,'id':1},
        'head_repository':{'full_name':intent.REPOSITORY},'run_started_at':(stamp-timedelta(minutes=2)).isoformat(),
        'updated_at':(stamp+timedelta(minutes=1)).isoformat()}
    producer={'id':123,'run_attempt':1,'path':'.github/workflows/build-server.yaml','event':'push','head_branch':'master',
        'head_sha':source,'status':'completed','conclusion':'success','head_repository':{'full_name':intent.REPOSITORY}}
    jobs=[{'name':'install','conclusion':'success'}]
    return run,jobs,data,producer


class DeploymentTests(unittest.TestCase):
    def test_archived_ack_is_bound_to_run_time_without_claiming_freshness_now(self):
        run,jobs,data,producer=fixture();proof=deployment.proof(run,jobs,data,producer)
        self.assertEqual(proof['acknowledgement'],'ARCHIVED_VERIFIED_DEPLOYMENT')
        for change in ('source','producer','failed','skip','time'):
            r,j,d,p=copy.deepcopy((run,jobs,data,producer))
            if change=='source':d['delivery']['readback']['source_revision']='f'*40
            if change=='producer':p['id']=124
            if change=='failed':d['status']='FAIL'
            if change=='skip':j[0]['conclusion']='skipped'
            if change=='time':d['delivery']['readback']['checked_at']=datetime.now(timezone.utc).isoformat()
            with self.subTest(change=change),self.assertRaises(ValueError):deployment.proof(r,j,d,p)

    def test_actual_zip_hash_single_member_and_api_ownership(self):
        run,_,_,_=fixture();blob=io.BytesIO()
        with zipfile.ZipFile(blob,'w') as archive:archive.writestr('receipt.json','{"public":"fixture"}')
        raw=blob.getvalue()
        row={'id':1,'name':'delivery-456-1','expired':False,'size_in_bytes':len(raw),'digest':'sha256:'+hashlib.sha256(raw).hexdigest(),
            'workflow_run':{'id':456,'repository_id':1,'head_repository_id':1,'head_sha':run['head_sha'],'head_branch':'master'}}
        class API:
            token='synthetic-token-never-sent'
            def read(self,path):return {'total_count':1,'artifacts':[row]}
        def receive(url,path,size):path.write_bytes(raw)
        with patch.object(deployment,'location',return_value='fixture'),patch.object(deployment,'receive',side_effect=receive):
            self.assertEqual(deployment.receipt(API(),run),{'public':'fixture'})
            row['digest']='sha256:'+'0'*64
            with self.assertRaises(ValueError):deployment.receipt(API(),run)
            row['workflow_run']['id']=457
            with self.assertRaises(ValueError):deployment.receipt(API(),run)
