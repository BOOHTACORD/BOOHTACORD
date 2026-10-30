"""Retain public controller/producer identity after the trusted routing decision."""
import json
import re
from tools.ci.native.process import ROOT
from ..provenance import validate


def record(run,result,env):
    repository=env['GITHUB_REPOSITORY'];source=validate(run,repository)
    def number(name):
        value=env[name]
        if not re.fullmatch('[1-9][0-9]{0,19}',value):raise ValueError('Invalid route controller identity')
        return int(value)
    if (not re.fullmatch('[0-9a-f]{40}',env['GITHUB_SHA']) or env['GITHUB_EVENT_NAME']!='workflow_run'
            or result['revision']!=source or result['run_id']!=run['id']
            or type(result['has_bundle']) is not bool or type(result['format_version']) is not int
            or result['format_version'] not in (1,2)
            or type(run.get('run_attempt')) is not int or run['run_attempt']<=0):
        raise ValueError('Route proof differs from verified controller or producer')
    return {'schema_version':1,'kind':'trusted-producer-route','status':'PASS','repository':repository,
        'controller':{'run_id':number('GITHUB_RUN_ID'),'run_attempt':number('GITHUB_RUN_ATTEMPT'),
                      'revision':env['GITHUB_SHA'],'event':env['GITHUB_EVENT_NAME']},
        'producer':{'run_id':run['id'],'run_attempt':run['run_attempt'],'source_revision':source,
                    'has_bundle':result['has_bundle'],'format_version':result['format_version']},
        'server_release_impact':result['has_bundle'] if result['format_version']==2 else None}


def publish(run,result,env):
    value=record(run,result,env);path=ROOT/'.out/delivery-route/route.json'
    path.parent.mkdir(parents=True,exist_ok=True)
    if path.is_symlink() or path.parent.resolve()!=path.parent:raise ValueError('Route proof must be direct')
    path.write_text(json.dumps(value,sort_keys=True)+'\n',encoding='utf-8')
