"""Read only this shadow execution's public reports and actual GitHub metadata."""
import json
import os
from pathlib import Path
from urllib.error import HTTPError,URLError
from urllib.request import Request,urlopen
from . import catalog,comparison
from .run import checked_source,ROOT


def read_inputs(root,source,run_id,attempt):
    root=Path(root)
    comparison.require(root.is_dir() and not root.is_symlink())
    expected={}
    for kind in ('legacy','fan-in'):
        for sample in comparison.SAMPLES:
            namespace='shadow-'+('old' if kind=='legacy' else 'new')+'-'+str(sample)
            expected['web-'+kind+'-'+namespace+'-'+source+'-'+str(run_id)+'-'+str(attempt)]=kind
    comparison.require({p.name for p in root.iterdir()}==set(expected))
    rows={'legacy':[],'fan-in':[]}
    for name,kind in expected.items():
        directory=root/name;filename='web-legacy.json' if kind=='legacy' else 'web-fan-in.json'
        comparison.require(not directory.is_symlink() and directory.is_dir()
                           and {p.name for p in directory.iterdir()}=={filename})
        path=directory/filename
        comparison.require(not path.is_symlink() and path.is_file() and path.stat().st_size<=65536)
        rows[kind].append(json.loads(path.read_text()))
    return rows['legacy'],rows['fan-in']


def read_api(path):
    token=os.environ.get('GITHUB_TOKEN','')
    comparison.require(bool(token))
    headers={'Authorization':'Bearer '+token,'Accept':'application/vnd.github+json',
             'X-GitHub-Api-Version':'2022-11-28','User-Agent':'boohtacord-web-shadow'}
    request=Request('https://api.github.com/repos/'+comparison.REPOSITORY+path,headers=headers)
    try:
        with urlopen(request,timeout=30) as response: data=response.read(4*1024*1024+1)
    except (HTTPError,URLError,TimeoutError):
        raise RuntimeError('Read-only shadow metadata is unavailable') from None
    comparison.require(len(data)<=4*1024*1024)
    return json.loads(data)


def main():
    source,dirty=checked_source();comparison.require(not dirty)
    identity=catalog.execution()
    comparison.require(identity['run_id']!='local' and identity['namespace']=='shadow-compare')
    run_id,attempt=int(identity['run_id']),int(identity['run_attempt'])
    path=ROOT/'.out/ci/web-shadow.json';path.parent.mkdir(parents=True,exist_ok=True)
    path.write_text(json.dumps({'source_revision':source,'status':'FAIL','run_id':run_id,'run_attempt':attempt})+'\n')
    needs=json.loads(os.environ['SHADOW_NEEDS'])
    comparison.require(set(needs)=={'legacy','profiles'} and all(v.get('result')=='success' for v in needs.values()))
    old,new=read_inputs(ROOT/'.out/ci/shadow-inputs',source,run_id,attempt)
    run=read_api('/actions/runs/'+str(run_id))
    jobs=read_api('/actions/runs/'+str(run_id)+'/jobs?filter=latest&per_page=100')
    comparison.require(run['head_sha']==source and run['id']==run_id and run['run_attempt']==attempt)
    result=comparison.compare(run,jobs,needs,old,new)
    path.write_text(json.dumps(result,indent=2,sort_keys=True)+'\n')
    if result['status']!='PASS':raise SystemExit(1)
    print('PASS: complete same-source Web comparison; runner cost and sample limits recorded')


if __name__=='__main__':main()
