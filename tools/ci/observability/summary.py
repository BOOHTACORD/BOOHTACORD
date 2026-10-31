"""Source-bound required-check triage without raw logs, actors, payloads or secret-bearing names."""
import argparse
import json
import os
from pathlib import Path
import re
import subprocess
from tools.ci.native.process import ROOT
from tools.ci.baseline.metrics import elapsed
from . import network
from .alerts import detect
from .triage import binding,classify,require

REPOSITORY='BOOHTACORD/BOOHTACORD'
SCOPES={'pr':'ci.yaml','server':'build-server.yaml','native':'native-master.yaml'}


def metadata(run_id,token):
    run=network.get('/actions/runs/'+run_id,token);require(type(run.get('id')) is int and run['id']==int(run_id));attempt=run.get('run_attempt')
    require(type(attempt) is int and 1<=attempt<=100)
    jobs=[]
    for page in range(1,6):
        rows=network.get('/actions/runs/'+run_id+'/attempts/'+str(attempt)+'/jobs?per_page=100&page='+str(page),token)
        batch=rows.get('jobs');require(isinstance(batch,list) and type(rows.get('total_count')) is int)
        jobs+=batch
        if len(jobs)==rows['total_count']:break
        require(batch and len(jobs)<rows['total_count'])
    require(len(jobs)==rows['total_count'] and len({j.get('id') for j in jobs})==len(jobs)
            and all(type(j.get('id')) is int and j['id']>0 and j.get('run_id')==int(run_id) for j in jobs))
    return run,jobs


def observe(scope,env,run,jobs,source,parents,needs):
    if scope=='manual':
        require(run.get('repository',{}).get('full_name')==REPOSITORY and run.get('head_sha')==source)
        source_binding='api_head_only'
    else:
        source_binding=binding(run,env,source,parents)
        require(run.get('path') in ('.github/workflows/'+SCOPES[scope],
                '.github/workflows/'+SCOPES[scope]+'@'+env.get('GITHUB_REF',''),
                '.github/workflows/'+SCOPES[scope]+'@'+source))
    result=classify(run,jobs)
    if scope!='manual':
        previous=env.get('CI_GATE_OUTCOME');require(previous in ('success','failure','cancelled'))
        cancelled=any(v.get('result')=='cancelled' for v in needs.values())
        failed=any(v.get('result')=='failure' for v in needs.values())
        result['outcome']='CANCELLED' if previous=='cancelled' or cancelled and not failed else 'FAIL' if result['failures'] or previous=='failure' else 'PASS'
        if run.get('event')=='pull_request' and result['outcome']=='CANCELLED':result['master_defect']=False
    if scope!='manual' and previous!='success' and not result['failures']:
        target={'pr':'ci-required','server':'server-quality','native':'native-required'}[scope]
        job=next((j for j in jobs if j.get('name')==target),{})
        result['failures']=[dict(component='aggregate',owner='CI/Triage',stage='aggregate-validation',step_number=None,
            critical_step='required aggregate validation/evidence; step metadata unavailable',job_id=job.get('id'),
            root_cause='UNVERIFIED',retry_test=False,reproduce='python -m tools.ci.required_gate.run' if scope=='pr' else
            'python -m tools.ci.master_quality.run '+scope)]
    result['alerts']=detect(run,jobs,result['failures'])
    outputs=needs.get('changes',{}).get('outputs',{})
    selected=['actual' if role=='actual_required' else role for role in ('contracts','backend','web','flutter','windows','actual_required') if outputs.get(role)=='true']
    base='https://github.com/'+REPOSITORY+'/actions/runs/'+str(run['id'])
    for failure in result['failures']:
        identity=failure['job_id'];failure['url']=base+('/job/'+str(identity) if identity else '')
    result.update(schema_version=1,scope=scope,metadata_complete=True,source_revision=source,api_head_sha=run['head_sha'],
        source_binding=source_binding,run_id=str(run['id']),run_attempt=str(run['run_attempt']),url=base,selected_gates=selected,
        components=[role for role in selected if role in ('backend','web','flutter','windows')],
        first_start_delay_seconds=elapsed(run.get('created_at'),min((j['started_at'] for j in jobs if j.get('started_at')),default=None)),
        completed_execution_seconds=sum(elapsed(j.get('started_at'),j.get('completed_at')) or 0 for j in jobs),
        total_execution_seconds=None,timing_note='Current aggregate may still be running; completed-job seconds only',
        retry_count=run['run_attempt']-1,confirmed_flake_rate=None,
        queue_seconds=None,queue_note='Job creation/start delay may include dependencies, dispatch and approvals',
        retry_policy='Only bounded Actions metadata GET transport retry; never repeat a gate/test/signing/health assertion')
    return result


def markdown(row):
    text=['## CI '+str(row.get('scope','triage'))+' — '+str(row['outcome']),
          'Source: `'+str(row.get('source_revision','unverified'))+'`',
          'Run/attempt: '+str(row.get('run_id','unknown'))+'/'+str(row.get('run_attempt','unknown')),
          'Source binding: '+str(row.get('source_binding','unverified')),
          'First start delay seconds: '+str(row.get('first_start_delay_seconds','unknown'))+
          '; completed-job execution seconds: '+str(row.get('completed_execution_seconds','unknown'))+
          '; retry count: '+str(row.get('retry_count','unknown'))+'; pure queue time: unknown.',
          '[Sanitized evidence and jobs]('+str(row.get('url','https://github.com/BOOHTACORD/BOOHTACORD/actions'))+')',
          'Selected gates: '+', '.join(row.get('selected_gates',[])),
          'Confirmed flake: UNKNOWN; reruns do not authorize ignored failures.','']
    for failure in row.get('failures',[]):
        text+=['- '+failure['component']+' — '+failure['critical_step']+'; owner '+failure['owner']+
               '. [Source job]('+failure['url']+'). Reproduce after restoring this source/toolchain/artifacts: `'+failure['reproduce']+'`.']
    if not row.get('metadata_complete'):text+=['BLOCKED: incomplete diagnostic metadata; required gates are not bypassed.']
    return '\n\n'.join(text)+'\n'


def main():
    parser=argparse.ArgumentParser();parser.add_argument('--scope',choices=[*SCOPES,'manual'],required=True);scope=parser.parse_args().scope
    directory=ROOT/'.out/ci/triage';directory.mkdir(parents=True,exist_ok=True)
    require(directory.resolve()==directory and not directory.is_symlink())
    row=dict(outcome='BLOCKED',scope=scope,metadata_complete=False)
    try:
        env=os.environ;run_id=env.get('OBSERVED_RUN_ID') if scope=='manual' else env.get('GITHUB_RUN_ID')
        source=env.get('OBSERVED_SOURCE') if scope=='manual' else env.get('GITHUB_SHA')
        require(re.fullmatch('[1-9][0-9]{0,19}',run_id or '') and re.fullmatch('[0-9a-f]{40}',source or ''))
        row.update(source_revision=source,run_id=run_id)
        parents=[]
        if scope!='manual':
            require(subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip()==source)
            parents=subprocess.check_output(['git','show','-s','--format=%P','HEAD'],cwd=ROOT,text=True).split()
        run,jobs=metadata(run_id,env.get('GITHUB_TOKEN'))
        row=observe(scope,env,run,jobs,source,parents,json.loads(env.get('TRIAGE_NEEDS','{}')))
    except Exception as error:row['failure_type']=type(error).__name__
    finally:
        (directory/(scope+'.json')).write_text(json.dumps(row,sort_keys=True)+'\n')
        if os.environ.get('GITHUB_STEP_SUMMARY'):
            with Path(os.environ['GITHUB_STEP_SUMMARY']).open('a') as stream:stream.write(markdown(row))
        print('CI triage '+scope+': '+row['outcome']+'; only sanitized metadata retained')
    return 0 if row['metadata_complete'] and (scope=='manual' or row['outcome']=='PASS') else 1


if __name__=='__main__':raise SystemExit(main())
