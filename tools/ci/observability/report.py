"""Recompute 30+ original #383 completed runs without new expensive acceptance or log access."""
import argparse
from collections import Counter,defaultdict
import hashlib
import json
from pathlib import Path
from tools.ci.baseline.metrics import distribution,elapsed,run_metrics
from .triage import classify,require
from .policy import load


def analyze(cohorts):
    policy=load()
    output={};recurring=defaultdict(list);observations=[];platforms=defaultdict(Counter);all_runs=[]
    for cohort,runs in cohorts.items():
        require(all(r.get('status')=='completed' for r in runs))
        all_runs+=runs;metrics=[run_metrics(r) for r in runs]
        output[cohort]=dict(n=len(runs),success_wall_seconds=distribution([m['wall_seconds'] for r,m in zip(runs,metrics) if r['conclusion']=='success']),
            first_start_delay_seconds=distribution([m['first_job_delay_seconds'] for m in metrics]),
            runner_execution_minutes=distribution([m['job_minutes'] for m in metrics]),
            failure_count=sum(r['conclusion']=='failure' for r in runs),cancelled_count=sum(r['conclusion']=='cancelled' for r in runs),
            rerun_rate=sum(r.get('run_attempt',1)>1 for r in runs)/len(runs) if runs else None,
            confirmed_flake_rate=None,required_green_seconds=None,queue_seconds=None)
        for run in runs:
            row=classify(run,run['jobs']);url='https://github.com/BOOHTACORD/BOOHTACORD/actions/runs/'+str(run['id'])
            observations.append(dict(run_id=run['id'],source_revision=run['head_sha'],source_kind='API workflow head; tested PR merge not verified',
                                     cohort=cohort,outcome=row['outcome'],url=url,confirmed_flake='UNKNOWN'))
            for failure in row['failures']:
                recurring[failure['fingerprint']].append(dict(failure,run_id=run['id'],source_revision=run['head_sha'],url=url))
            for job in run['jobs']:
                platforms[job.get('platform','unknown')][job.get('conclusion','unknown')]+=1
    require(len({r['id'] for r in all_runs})==len(all_runs) and len(all_runs)>=30)
    failures=[dict(fingerprint=key,n=len(rows),component=rows[0]['component'],stage=rows[0]['stage'],owner=rows[0]['owner'],
                   root_cause='UNVERIFIED',retry_test=False,occurrences=rows) for key,rows in recurring.items()]
    failures.sort(key=lambda row:(-row['n'],row['fingerprint']))
    alerts=[dict(kind='recurring-failed-gate',severity='triage',component=row['component'],count=row['n'],urls=[r['url'] for r in row['occurrences']]) for row in failures if row['n']>=policy['recurring_failure_warning_count']]
    for name,row in output.items():
        if (row['first_start_delay_seconds']['p95'] or 0)>policy['first_start_delay_warning_seconds']:alerts.append(dict(kind='start-delay-spike',cohort=name,severity='triage'))
        if (row['success_wall_seconds']['p95'] or 0)>policy['workflow_wall_warning_seconds']:alerts.append(dict(kind='workflow-wall-p95-over-20min',cohort=name,severity='triage'))
    return dict(schema_version=1,scope='historical-metadata-analysis',collection_status='PASS',sample_count=len(all_runs),
        cohorts=output,platform_job_outcomes=dict(platforms),recurring_failures=failures,observations=observations,alerts=alerts,
        confirmed_flake_rate=None,billing_minutes=None,required_green_seconds=None,
        limitations=['Repeated failures/reruns do not prove flakiness or justify a retry/quarantine.',
            'API head SHA is not necessarily the tested synthetic PR merge SHA.',
            'Start delays include dispatch, dependencies and approvals; pure queue time is unknown.',
            'Successful workflow wall time is a proxy; owner required checks and exact healthy readback are separate evidence.',
            'Job-minutes sum all attempts without billing rounding or platform cost multipliers.',
            'Root causes are unverified: metadata collection never reads logs, user data, credentials or artifact contents.'])


def collect(cache,frozen):
    require(json.loads((cache/'manifest.json').read_text()).get('completed_at'))
    cohorts={};hashes={}
    for path in sorted(frozen.glob('*.json')):
        selected=json.loads(path.read_text())
        if not isinstance(selected,list):continue
        rows=[]
        for observed in selected:
            identity=observed['id'];require(type(identity) is int and identity>0)
            source=cache/'runs'/(str(identity)+'.json');raw=source.read_bytes();row=json.loads(raw)
            require(all(row.get(k)==observed.get(k) for k in ('id','head_sha','path','event','status','conclusion','run_attempt')))
            hashes[str(identity)]=hashlib.sha256(raw).hexdigest();rows.append(row)
        cohorts[path.stem]=rows
    return cohorts,hashes


def main():
    parser=argparse.ArgumentParser();parser.add_argument('--cache',type=Path,required=True);parser.add_argument('--frozen',type=Path,required=True)
    parser.add_argument('--output',type=Path,required=True);args=parser.parse_args()
    cohorts,hashes=collect(args.cache,args.frozen);result=analyze(cohorts);result['input_sha256']=hashes
    args.output.parent.mkdir(parents=True,exist_ok=True);args.output.write_text(json.dumps(result,indent=2)+'\n')
    print('Historical CI metadata analyzed: '+str(result['sample_count'])+' complete source-linked runs; flake causes unverified')


if __name__=='__main__':main()
