"""Read only this manual execution's source-bound public backend reports."""
import argparse
import json
import os
from tools.ci.native.process import ROOT
from tools.ci.web_suites.measure import read_api
from tools.ci.artifact_policy.capture_data import strict_json, safe_json
from .run import checked_source
from .results import execution, read_reports, require
from .shadow_compare import compare


def read(path):
    require(path.is_file() and not path.is_symlink() and path.stat().st_size<=65536)
    value=strict_json(path.read_bytes());safe_json(value);return value


def main():
    parser=argparse.ArgumentParser();parser.add_argument('--prepare-only',action='store_true');args=parser.parse_args()
    output=ROOT/'.out/ci/backend-shadow.json';output.parent.mkdir(parents=True,exist_ok=True)
    output.write_text(json.dumps(dict(schema_version=1,status='FAIL'))+'\n')
    source=checked_source();identity=execution();require(identity['run_id']!='local')
    run_id,attempt=int(identity['run_id']),int(identity['run_attempt'])
    output.write_text(json.dumps(dict(schema_version=1,status='FAIL',source_revision=source,run_id=run_id,run_attempt=attempt))+'\n')
    if args.prepare_only:return
    needs=json.loads(os.environ['BACKEND_SHADOW_NEEDS'])
    require(set(needs)=={'legacy','profiles'} and all(v.get('result')=='success' for v in needs.values()))
    root=ROOT/'.out/ci/backend-shadow-inputs'
    legacy=read(root/'legacy/backend-shadow-legacy.json')
    parts=read_reports(root/'parts');fanin=read(root/'fan-in/backend-fan-in.json')
    run=read_api('/actions/runs/'+str(run_id))
    jobs=read_api('/actions/runs/'+str(run_id)+'/jobs?filter=latest&per_page=100')
    require(run['id']==run_id and run['run_attempt']==attempt and run['head_sha']==source)
    result=compare(run,jobs,needs,legacy,parts,fanin)
    safe_json(result);output.write_text(json.dumps(result,indent=2,sort_keys=True)+'\n')
    print('PASS: full same-source backend functional comparison; one paired sample, no statistical speed claim')


if __name__=='__main__':main()
