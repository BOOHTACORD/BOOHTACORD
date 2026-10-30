"""Only an independently proven native-only route may omit a deployment receipt."""
import re
from tools.release.delivery.routing import decision
from ..intent import REPOSITORY,require
from .artifact import document


def probe(api,run,jobs):
    installed=[row for row in jobs if row.get('name')=='install']
    if not installed or any(row.get('conclusion')!='skipped' for row in installed):return None
    require(run.get('path')=='.github/workflows/deploy-production.yaml' and run.get('event')=='workflow_run'
        and run.get('head_branch')=='master' and run.get('status')=='completed' and run.get('conclusion')=='success'
        and run.get('repository',{}).get('full_name')==REPOSITORY
        and run.get('head_repository',{}).get('full_name')==REPOSITORY
        and re.fullmatch('[0-9a-f]{40}',run.get('head_sha',''))
        and type(run.get('run_attempt')) is int and run['run_attempt']>0)
    require(len(jobs)==2 and {row.get('name') for row in jobs}=={'route','install'}
        and len({row.get('id') for row in jobs})==2
        and all(type(row.get('id')) is int and row['id']>0 and type(row.get('run_id')) is int
                and type(row.get('run_attempt')) is int
                and row.get('run_id')==run['id'] and row.get('run_attempt')==run['run_attempt']
                and row.get('status')=='completed' for row in jobs)
        and next(row for row in jobs if row['name']=='route')['conclusion']=='success')
    route,route_artifact=document(api,run,f'trusted-route-{run["id"]}-{run["run_attempt"]}','route.json')
    require(type(route.get('schema_version')) is int and route.get('schema_version')==1
        and route.get('kind')=='trusted-producer-route'
        and route.get('status')=='PASS' and route.get('repository')==REPOSITORY
        and route.get('server_release_impact') is False
        and route.get('controller')=={'run_id':run['id'],'run_attempt':run['run_attempt'],
                                     'revision':run['head_sha'],'event':'workflow_run'})
    record=route['producer'];identity=record['run_id']
    require(type(identity) is int and 0<identity<10**20)
    producer=api.read(f'/actions/runs/{identity}');require(producer['id']==identity
        and producer.get('repository',{}).get('full_name')==REPOSITORY)
    producer_jobs=api.jobs(identity)
    selected=decision(producer,{'total_count':len(producer_jobs),'jobs':producer_jobs},REPOSITORY)
    require(selected['format_version']==2 and selected['has_bundle'] is False
        and record=={'run_id':identity,'run_attempt':producer['run_attempt'],
                     'source_revision':selected['revision'],'has_bundle':False,'format_version':2})
    source=selected['revision'];attempt=producer['run_attempt']
    quality,quality_artifact=document(api,producer,f'quality-master-server-{source}-{identity}-{attempt}','master-server.json')
    require(type(quality.get('schema_version')) is int and quality.get('schema_version')==1
        and quality.get('status')=='PASS' and quality.get('scope')=='server'
        and quality.get('source_revision')==source and quality.get('run_id')==str(identity)
        and quality.get('run_attempt')==str(attempt) and quality.get('server_release_impact') is False
        and re.fullmatch('[0-9a-f]{64}',quality.get('map_sha256',''))
        and quality.get('jobs')=={'changes':'success','contracts':'success','backend':'skipped','web':'skipped'})
    for previous in (run,producer):
        current=api.read(f'/actions/runs/{previous["id"]}')
        require(all(current.get(key)==previous.get(key) for key in
                    ('id','run_attempt','head_sha','status','conclusion','path','event','head_branch')))
    return {'status':'NOT_RUN','reason':'native_only_no_server_release','source_revision':source,
        'controller_revision':run['head_sha'],'run_id':run['id'],'run_attempt':run['run_attempt'],
        'producer_run_id':identity,'producer_run_attempt':attempt,'server_release_impact':False,
        'route_artifact':route_artifact,'master_quality_artifact':quality_artifact}
