"""Compare complete same-source shadow samples using actual GitHub job intervals."""
from tools.ci.runner_pool.routing import measurement_pool
from datetime import datetime
import math
import re
from . import catalog

REPOSITORY = 'BOOHTACORD/BOOHTACORD'
SAMPLES = (1,2,3)


def require(value):
    if not value:
        raise ValueError('Incomplete or inconsistent source-bound Web shadow measurement')


def positive(value):
    require(type(value) in (int,float) and math.isfinite(value) and value>0)
    return value


def instant(value):
    require(isinstance(value,str))
    result=datetime.fromisoformat(value.replace('Z','+00:00'))
    require(result.tzinfo is not None)
    return result.timestamp()


def interval(job):
    require(job['status']=='completed' and job['conclusion']=='success')
    created,start,end=(instant(job[name]) for name in ('created_at','started_at','completed_at'))
    require(created<=start<end)
    return created,start,end


def percentiles(values):
    require(len(values)==3)
    ordered=sorted(positive(value) for value in values)
    return {'p50':round(ordered[1],6),'p95':round(ordered[2],6)}


def compare(run,jobs,needs,old,new):
    try:
        return _compare(run,jobs,needs,old,new)
    except (KeyError,TypeError,AttributeError,IndexError,OverflowError) as error:
        raise ValueError('Malformed Web shadow measurement') from error


def _compare(run,jobs,needs,old,new):
    source=run['head_sha'];run_id=run['id'];attempt=run['run_attempt']
    require(isinstance(source,str) and re.fullmatch('[0-9a-f]{40}',source)
            and type(run_id) is int and run_id>0 and type(attempt) is int and attempt>0)
    require(run['repository']['full_name']==REPOSITORY and run['head_repository']['full_name']==REPOSITORY
            and run['path']=='.github/workflows/web-ci-shadow.yaml'
            and run['event'] in ('workflow_dispatch','push'))
    require(set(needs)=={'legacy','profiles'} and all(v.get('result')=='success' for v in needs.values()))
    reference,plan=catalog.baseline(),catalog.plan()
    require(len(old)==len(new)==len(SAMPLES))
    expected_jobs={'compare'}
    roles=['fast','sfu','frontend',*[f'browser ({p})' for p in catalog.BROWSER_PROFILES]]
    for sample in SAMPLES:
        expected_jobs.add('legacy-'+str(sample))
        expected_jobs.update('profiles-'+str(sample)+' / '+role for role in roles)
    require(jobs['total_count']==len(jobs['jobs'])==len(expected_jobs)
            and {row['name'] for row in jobs['jobs']}==expected_jobs)
    require(len({row['id'] for row in jobs['jobs']})==len(expected_jobs))
    require(all(type(row['id']) is int and row['id']>0 and row['run_id']==run_id and row['run_attempt']==attempt
                and row['head_sha']==source  for row in jobs['jobs']))
    pool=measurement_pool(jobs['jobs'])
    by_name={row['name']:row for row in jobs['jobs']}
    arms={'legacy':[],'profiles':[]}
    for arm,rows in [('legacy',old),('profiles',new)]:
        seen=set()
        for row in rows:
            require(row['source_revision']==source and row['status']=='PASS')
            identity=row['execution'];namespace=identity['namespace']
            match=re.fullmatch('shadow-'+('old' if arm=='legacy' else 'new')+'-([123])',namespace)
            require(match is not None and identity=={'run_id':str(run_id),'run_attempt':str(attempt),'namespace':namespace})
            sample=int(match[1]);require(sample not in seen);seen.add(sample)
            if arm=='legacy':
                require(set(row)=={'source_revision','status','operations','legacy_reference_revision','legacy_source_sha256','seconds','execution'})
                require(row['operations']==list(reference['operations'])
                        and row['legacy_reference_revision']==reference['source_revision']
                        and row['legacy_source_sha256']==reference['source_sha256'])
                selected=[by_name['legacy-'+str(sample)]]
                duration=positive(row['seconds'])
            else:
                require(set(row)=={'source_revision','status','profiles','plan_sha256','observed_profile_seconds','checked_operations','execution'})
                require(row['profiles']==sorted(plan['profiles']) and row['plan_sha256']==catalog.digest(plan)
                        and row['checked_operations']==sum(map(len,plan['profiles'].values()))
                        and set(row['observed_profile_seconds'])==set(plan['profiles']))
                selected=[by_name['profiles-'+str(sample)+' / '+role] for role in roles]
                fanout=[j for j in selected if not j['name'].endswith(' / frontend')]
                require(all(type(j.get('runner_id')) is int and j['runner_id']>0 for j in fanout)
                        and len({j['runner_id'] for j in fanout})==len(plan['profiles']))
                for profile,seconds in row['observed_profile_seconds'].items():
                    role={'fast':'fast','sfu-network':'sfu'}.get(profile,'browser ('+profile+')')
                    job=by_name['profiles-'+str(sample)+' / '+role]
                    _,start,end=interval(job)
                    require(positive(seconds)<=end-start+1)
                duration=max(row['observed_profile_seconds'].values())
            times=[interval(job) for job in selected]
            start=min(t[1] for t in times);end=max(t[2] for t in times)
            require(duration<=end-start+1)
            arms[arm].append({'sample':sample,'critical_seconds':round(end-start,6),
                              'runner_minutes':round(sum(t[2]-t[1] for t in times)/60,6),
                              'created_to_first_start_seconds':round(start-min(t[0] for t in times),6),
                              'driver_critical_seconds':duration,'job_ids':[j['id'] for j in selected]})
        require(seen==set(SAMPLES))
        arms[arm].sort(key=lambda r:r['sample'])
    summary={arm:{'n':3,**{field:percentiles([r[field] for r in rows])
                           for field in ('critical_seconds','runner_minutes')}} for arm,rows in arms.items()}
    faster=all(summary['profiles']['critical_seconds'][p]<summary['legacy']['critical_seconds'][p] for p in ('p50','p95'))
    return {'schema_version':1,'source_revision':source,'run_id':run_id,'run_attempt':attempt,
            'runner_pool':pool,'status':'PASS' if faster else 'NO_GAIN','samples':arms,'summary':summary,
            'legacy_reference_revision':reference['source_revision'],'legacy_source_sha256':reference['source_sha256'],
            'plan_sha256':catalog.digest(plan),
            'coverage':{'legacy_operations':len(reference['operations']),
                        'profile_operations':sum(map(len,plan['profiles'].values())),'original_coverage_preserved':True},
            'failure_observation':{'legacy_failed':0,'profiles_failed':0,'samples_per_arm':3},
            'scope':'Actual job execution including SDK/setup/uploads/fan-in; n=3 nearest-rank descriptive statistics. Initial wait can include deliberate serial sampling. No general CI SLO, flake-rate or media capacity claim.'}
