"""Bounded read-only GitHub metadata; credentials never follow redirects."""
import json
import os
from urllib.request import Request, build_opener
from tools.release.delivery.artifact_download import NoRedirect
from .intent import REPOSITORY, require


class GitHub:
    def __init__(self,token=None):self.token=token if token is not None else os.environ.get('GH_TOKEN',os.environ.get('GITHUB_TOKEN',''))
    def read(self,path):
        require(isinstance(path,str) and path.startswith('/') and '..' not in path and '\\' not in path)
        headers={'Accept':'application/vnd.github+json'}
        if self.token:headers['Authorization']='Bearer '+self.token
        request=Request('https://api.github.com/repos/'+REPOSITORY+path,headers=headers)
        try:
            with build_opener(NoRedirect()).open(request,timeout=20) as response:
                require(response.status==200);raw=response.read(2_000_001)
            require(len(raw)<=2_000_000)
            return json.loads(raw)
        except Exception:raise ValueError('Cannot read bounded promotion metadata') from None
    def jobs(self,run_id):
        rows=[];total=None
        for page in range(1,21):
            value=self.read(f'/actions/runs/{run_id}/jobs?filter=latest&per_page=100&page={page}')
            require(type(value['total_count']) is int and 0<=value['total_count']<=2000
                    and (total is None or total==value['total_count']) and isinstance(value['jobs'],list))
            total=value['total_count'];rows.extend(value['jobs'])
            if len(rows)==total:return rows
            require(len(rows)<total and value['jobs'])
        raise ValueError('Truncated promotion jobs')
