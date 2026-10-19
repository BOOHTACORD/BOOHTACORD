"""Authenticate run metadata and environment review; never accept a caller's approval flag."""
import json
import os
from urllib.request import Request,urlopen
from .policy import require,REPO


def validate(plan,run,reviews):
    require(run.get('id')==int(plan['run_id']) and run.get('head_sha')==plan['source_revision']
            and run.get('run_attempt')==1 and run.get('event')=='workflow_dispatch' and run.get('head_branch')=='master'
            and run.get('repository',{}).get('full_name')==REPO and run.get('head_repository',{}).get('full_name')==REPO
            and run.get('path')=='.github/workflows/'+plan['workflow'] and run.get('actor',{}).get('id')==plan['actor_id'])
    require(isinstance(reviews,list) and len(reviews)<=100)
    matches=[row for row in reviews if any(e.get('name')==plan['environment'] for e in row.get('environments',[]))]
    require(matches and all(row.get('state')=='approved' and type(row.get('user',{}).get('id')) is int
                           and row['user']['id']>0 for row in matches))
    reviewers=sorted(set(row['user']['id'] for row in matches))
    require(plan['risk']!='mutation' or all(value!=plan['actor_id'] for value in reviewers))
    return reviewers


def read(path):
    token=os.environ.get('GITHUB_TOKEN','');require(bool(token))
    request=Request('https://api.github.com/repos/'+REPO+path,headers={
        'Authorization':'Bearer '+token,'Accept':'application/vnd.github+json','X-GitHub-Api-Version':'2022-11-28',
        'User-Agent':'boohtacord-operator-audit'})
    try:
        with urlopen(request,timeout=20) as response:raw=response.read(1_000_001)
        require(len(raw)<=1_000_000);return json.loads(raw)
    except Exception:raise ValueError('Authenticated operator approval is unavailable') from None


def verify(plan):
    base='/actions/runs/'+plan['run_id']
    return validate(plan,read(base),read(base+'/approvals'))
