import copy
import hashlib
import io
import json
import os
from pathlib import Path
import tempfile
from unittest.mock import patch
import zipfile
from tools.release.delivery import artifact_download
from .. import readback, deployment, endpoint
from ..intent import REPOSITORY


def workflow(identity, path, source, event):
    return {'id':identity,'run_attempt':2,'head_sha':source,'head_branch':'master',
            'path':path,'event':event,'status':'completed','conclusion':'success',
            'repository':{'id':1,'full_name':REPOSITORY},
            'head_repository':{'id':1,'full_name':REPOSITORY}}


def jobs(identity, rows):
    return [{'id':identity*10+index,'run_id':identity,'run_attempt':2,'status':'completed',
             'name':name,'conclusion':outcome} for index,(name,outcome) in enumerate(rows,1)]


class API:
    token='synthetic-never-sent'
    def __init__(self):
        self.runs={123:workflow(123,'.github/workflows/build-server.yaml','a'*40,'push'),
                   456:workflow(456,'.github/workflows/deploy-production.yaml','b'*40,'workflow_run')}
        self.job_rows={123:jobs(123,[('changes','success'),('contracts / contracts','success'),
            ('backend','skipped'),('web','skipped'),('server-quality','success'),('bundle','skipped')]),
            456:jobs(456,[('route','success'),('install','skipped')])}
        self.route={'schema_version':1,'kind':'trusted-producer-route','status':'PASS','repository':REPOSITORY,
            'controller':{'run_id':456,'run_attempt':2,'revision':'b'*40,'event':'workflow_run'},
            'producer':{'run_id':123,'run_attempt':2,'source_revision':'a'*40,
                        'has_bundle':False,'format_version':2},'server_release_impact':False}
        self.quality={'schema_version':1,'status':'PASS','scope':'server','run_id':'123','run_attempt':'2',
            'source_revision':'a'*40,'server_release_impact':False,'map_sha256':'c'*64,
            'jobs':{'changes':'success','contracts':'success','backend':'skipped','web':'skipped'}}
        self.blobs={};self.rows={};self.refresh()

    def refresh(self):
        for identity,owner,name,member,value in [
            (1,456,'trusted-route-456-2','route.json',self.route),
            (2,123,'quality-master-server-'+('a'*40)+'-123-2','master-server.json',self.quality)]:
            stream=io.BytesIO()
            with zipfile.ZipFile(stream,'w') as archive:archive.writestr(member,json.dumps(value))
            raw=stream.getvalue();self.blobs[identity]=raw;run=self.runs[owner]
            self.rows[owner]=[{'id':identity,'name':name,'expired':False,'size_in_bytes':len(raw),
                'digest':'sha256:'+hashlib.sha256(raw).hexdigest(),'workflow_run':{
                    'id':owner,'repository_id':1,'head_repository_id':1,'head_sha':run['head_sha'],'head_branch':'master'}}]

    def read(self,path):
        parts=path.split('/');identity=int(parts[3])
        if len(parts)==4:return copy.deepcopy(self.runs[identity])
        if parts[4]=='artifacts?per_page=100':
            return {'total_count':len(self.rows[identity]),'artifacts':copy.deepcopy(self.rows[identity])}
        raise AssertionError('Unexpected API request')

    def jobs(self,identity):return copy.deepcopy(self.job_rows[identity])
    def location(self,identity,token):return 'fixture:'+str(identity)
    def receive(self,uri,path,size):
        raw=self.blobs[int(uri.split(':')[1])];assert len(raw)==size;path.write_bytes(raw)


def execute(api):
    with tempfile.TemporaryDirectory() as directory:
        with patch.object(readback,'ROOT',Path(directory)),patch.object(readback,'GitHub',return_value=api),\
             patch.dict(os.environ,{'DEPLOY_RUN_ID':'456'}),\
             patch.object(artifact_download,'location',side_effect=api.location),\
             patch.object(artifact_download,'receive',side_effect=api.receive),\
             patch.object(deployment,'receipt',wraps=deployment.receipt) as real,\
             patch.object(endpoint,'observe') as observe:
            try:readback.main()
            except SystemExit:pass
            value=json.loads((Path(directory)/'.out/windows-promotion-readback/trace.json').read_text())
            return value,real.call_count,observe.call_count
