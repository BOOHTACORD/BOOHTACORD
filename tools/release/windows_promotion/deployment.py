"""Verify retained deployment evidence without presenting an old ACK as fresh now."""
from datetime import datetime
import hashlib
import json
from pathlib import Path
import re
import stat
import tempfile
import zipfile
from tools.release.delivery.artifact_download import location, receive
from tools.release.delivery.receipt import authority, STEPS
from tools.release.delivery.provenance import validate as producer_source
from . import intent


def proof(run,jobs,receipt,producer):
    intent.require(run.get('path')=='.github/workflows/deploy-production.yaml' and run.get('event')=='workflow_run'
        and run.get('head_branch')=='master' and run.get('status')=='completed' and run.get('conclusion')=='success'
        and run.get('repository',{}).get('full_name')==intent.REPOSITORY
        and run.get('head_repository',{}).get('full_name')==intent.REPOSITORY)
    installed=[j for j in jobs if j.get('name')=='install']
    intent.require(len(installed)==1 and installed[0].get('conclusion')=='success')
    intent.require(receipt.get('kind')=='production-delivery' and receipt.get('status')=='PASS'
        and receipt.get('remote_completion')=='FRESH_READBACK_VERIFIED'
        and receipt.get('stages')=={name:'success' for name in STEPS})
    source=producer_source(producer,intent.REPOSITORY)
    record=authority(receipt['producer']);intent.require(record['source_revision']==source
        and record['run_id']==producer['id'] and record['run_attempt']==producer['run_attempt'])
    delivery=receipt['delivery'];ack=delivery['readback']
    intent.require(delivery['status']=='PASS' and delivery['source_revision']==source and ack['status']=='PASS'
        and ack['source_revision']==source and ack['sources']=={'api':source,'web':source}
        and ack['health']=='PASS' and ack['persistent_volumes']=='PASS')
    started=datetime.fromisoformat(run['run_started_at'].replace('Z','+00:00'))
    finished=datetime.fromisoformat(run['updated_at'].replace('Z','+00:00'))
    checked=datetime.fromisoformat(ack['checked_at'].replace('Z','+00:00'))
    intent.require(started.tzinfo and finished.tzinfo and checked.tzinfo and -30<=(checked-started).total_seconds()
                   and (checked-finished).total_seconds()<=30)
    return {'status':'PASS','source_revision':source,'run_id':run['id'],'run_attempt':run['run_attempt'],
        'url':f'https://github.com/{intent.REPOSITORY}/actions/runs/{run["id"]}',
        'producer_url':f'https://github.com/{intent.REPOSITORY}/actions/runs/{producer["id"]}',
        'acknowledgement':'ARCHIVED_VERIFIED_DEPLOYMENT','checked_at':ack['checked_at']}


def receipt(api,run):
    value=api.read(f'/actions/runs/{run["id"]}/artifacts?per_page=100')
    rows=value['artifacts'];intent.require(value['total_count']==len(rows) and len(rows)<=100)
    matches=[row for row in rows if row.get('name')==f'delivery-{run["id"]}-{run["run_attempt"]}']
    intent.require(len(matches)==1);row=matches[0];owner=row.get('workflow_run',{})
    intent.require(row.get('expired') is False and type(row.get('size_in_bytes')) is int and 0<row['size_in_bytes']<=131072
        and re.fullmatch('sha256:[0-9a-f]{64}',row.get('digest','')) and owner.get('id')==run['id']
        and owner.get('repository_id')==run['repository']['id'] and owner.get('head_repository_id')==run['repository']['id']
        and owner.get('head_sha')==run['head_sha'] and owner.get('head_branch')=='master')
    with tempfile.TemporaryDirectory(prefix='windows-promotion-receipt-') as name:
        path=Path(name).resolve()/'artifact.zip'
        receive(location(row['id'],api.token),path,row['size_in_bytes'])
        intent.require('sha256:'+hashlib.sha256(path.read_bytes()).hexdigest()==row['digest'])
        with zipfile.ZipFile(path) as archive:
            items=archive.infolist();intent.require(len(items)==1)
            item=items[0]
            intent.require(item.filename=='receipt.json' and 0<item.file_size<=65536 and not item.flag_bits&1
                and item.compress_type in (zipfile.ZIP_STORED,zipfile.ZIP_DEFLATED)
                and stat.S_IFMT(item.external_attr>>16) in (0,stat.S_IFREG))
            return json.loads(archive.read(item))
