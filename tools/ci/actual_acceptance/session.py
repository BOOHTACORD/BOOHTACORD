"""A case owns one disposable isolated Linux guest lease and one exact Docker label namespace."""
from tools.ci.runner_pool.routing import isolated_linux
import hashlib
import json
import os
import platform
from pathlib import Path
import re
import secrets
import subprocess
import time
from .plan import require

LABEL='boohtacord.qa.owner'


def hosted():
    require(platform.system()=='Linux' and os.environ.get('GITHUB_ACTIONS')=='true'
            and isolated_linux(os.environ))


def identity(source,profile,env):
    require(re.fullmatch('[0-9a-f]{40}',source) and profile in ('lifecycle','next','sfu'))
    run,attempt,job=(env.get(key,'') for key in ('GITHUB_RUN_ID','GITHUB_RUN_ATTEMPT','GITHUB_JOB'))
    require(re.fullmatch('[1-9][0-9]*',run) and re.fullmatch('[1-9][0-9]*',attempt) and re.fullmatch('[A-Za-z0-9_-]{1,100}',job))
    namespace=hashlib.sha256((source+profile+run+attempt+job+secrets.token_hex(16)).encode()).hexdigest()[:16]
    return {'source_revision':source,'profile':profile,'run_id':run,'run_attempt':attempt,'job':job,'owner':'qa-client-'+namespace,
            'port_namespace':('disposable-github-hosted-vm/' if env.get('RUNNER_ENVIRONMENT')=='github-hosted' else 'disposable-self-hosted-guest/')+run+'/'+attempt+'/'+job+'/'+namespace}


def output(*args):return subprocess.check_output(args,text=True,stderr=subprocess.DEVNULL,timeout=15).strip()
def run(*args):return subprocess.run(args,check=True,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,timeout=15)


def cleanup(owner):
    require(re.fullmatch('qa-client-[0-9a-f]{16}',owner))
    deadline=time.monotonic()+120
    for kind in ('container','network','volume','image'):
        args=['docker',kind,'ls','--filter','label='+LABEL+'='+owner,'--format','{{.ID}}' if kind in ('container','image') else '{{.Name}}']
        if kind=='container':args.insert(3,'--all')
        rows=output(*args).splitlines();require(len(rows)<=100)
        for name in rows:
            require(time.monotonic()<deadline and re.fullmatch(r'(?:sha256:)?[0-9a-f]{12,64}|qa-client-[0-9a-f]{16}(?:-[a-z0-9-]+)?',name))
            template='{{index .'+('Config.Labels' if kind in ('container','image') else 'Labels')+' "'+LABEL+'"}}'
            require(output('docker',kind,'inspect',name,'--format',template)==owner)
            run('docker',kind,'rm',*(['--force'] if kind=='container' else []),name)
        require(not output(*args))
    return True


def child_environment(row):
    # The real fixtures generate their own passwords. No CI API/upload tokens,
    # SSH credentials or caller signing inputs enter a product process.
    env={k:v for k,v in os.environ.items() if not any(word in k.upper() for word in ('TOKEN','PASSWORD','SECRET','SSH_'))}
    env.update(BOOHTACORD_QA_OWNER=row['owner'],VITE_PUBLIC_ORIGIN='https://localhost:4810')
    return env
