"""A successful run must be fresh, complete and for the exact candidate branch/SHA."""
import re
from .intent import REPOSITORY, require


def validate(run,jobs,branch,sha,run_id=None,attempt=None):
    require(type(run.get('id')) is int and run['id']>0 and type(run.get('run_attempt')) is int and run['run_attempt']>0)
    require((run_id is None or run['id']==run_id) and (attempt is None or run['run_attempt']==attempt))
    require(run.get('path')=='.github/workflows/ci.yaml' and run.get('event')=='workflow_dispatch'
            and run.get('head_sha')==sha and run.get('head_branch')==branch
            and run.get('status')=='completed' and run.get('conclusion')=='success'
            and run.get('repository',{}).get('full_name')==REPOSITORY
            and run.get('head_repository',{}).get('full_name')==REPOSITORY)
    required=[job for job in jobs if job.get('name')=='ci-required']
    require(len(required)==1 and required[0].get('conclusion')=='success' and required[0].get('status')=='completed')
    return {'schema_version':1,'status':'PASS','source_revision':sha,'branch':branch,
        'run_id':run['id'],'run_attempt':run['run_attempt'],
        'url':f'https://github.com/{REPOSITORY}/actions/runs/{run["id"]}'}
