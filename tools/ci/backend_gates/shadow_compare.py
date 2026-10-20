"""Full same-source functional parity; one pair does not establish p50/p95."""
from datetime import datetime
import math
import re
from .results import PROFILES, OPERATIONS, require
from tools.ci.runner_pool.routing import measurement_pool

LEGACY_OPERATIONS=('go:database-preflight','go:test:all:uncached','go:no-skip','go:vet:all','go:build:all',
                   'screen-share:matrix','api:normal:2:20','api:reconnect:2:20','api:uploads:2:20:1024',
                   'api:nat_auth:1:20','api:faults:2:40')
REFERENCE_REVISION='d552352482187b9822768161f8507d59cbf2e19e'
NAMES={'legacy','profiles / static','profiles / database','profiles / load','profiles / backend','compare'}


def positive(value):
    require(type(value) in (int,float) and math.isfinite(value) and value>0)
    return value


def interval(job):
    require(job['status']=='completed' and job['conclusion']=='success')
    created,start,end=(datetime.fromisoformat(job[k].replace('Z','+00:00'))
                       for k in ('created_at','started_at','completed_at'))
    require(all(d.tzinfo is not None for d in (created,start,end)) and created<=start<end)
    return start.timestamp(),end.timestamp()


def compare(run,jobs,needs,legacy,parts,fanin):
    try:
        source=run['head_sha'];run_id=run['id'];attempt=run['run_attempt']
        require(isinstance(source,str) and re.fullmatch('[0-9a-f]{40}',source)
                and type(run_id) is int and run_id>0 and type(attempt) is int and attempt>0)
        require(run['repository']['full_name']==run['head_repository']['full_name']=='Egkurilov/BOOHTACORD'
                and run['event']=='workflow_dispatch' and run['head_branch']=='master'
                and run['path']=='.github/workflows/backend-ci-shadow.yaml')
        require(set(needs)=={'legacy','profiles'} and all(v.get('result')=='success' for v in needs.values()))
        require(jobs['total_count']==len(jobs['jobs'])==len(NAMES)
                and {j['name'] for j in jobs['jobs']}==NAMES
                and len({j['id'] for j in jobs['jobs']})==len(NAMES))
        require(all(type(j['id']) is int and j['id']>0 and type(j['run_id']) is int and j['run_id']==run_id
                    and type(j['run_attempt']) is int and j['run_attempt']==attempt
                    and j['head_sha']==source for j in jobs['jobs']))
        pool=measurement_pool(jobs['jobs'])
        by_name={j['name']:j for j in jobs['jobs']}
        identity={'run_id':str(run_id),'run_attempt':str(attempt)}
        current_operations=[name for names in OPERATIONS.values() for name in names]
        require(len(current_operations)==len(LEGACY_OPERATIONS)
                and set(current_operations)==set(LEGACY_OPERATIONS))
        require(set(legacy)=={'schema_version','source_revision','status','execution','operations','seconds','coverage_reference_revision'}
                and type(legacy['schema_version']) is int and legacy['schema_version']==1 and legacy['source_revision']==source
                and legacy['status']=='PASS' and legacy['execution']==identity
                and legacy['coverage_reference_revision']==REFERENCE_REVISION
                and legacy['operations']==list(LEGACY_OPERATIONS))
        require(isinstance(parts,list) and len(parts)==len(PROFILES))
        durations={}
        for row in parts:
            require(set(row)=={'source_revision','profile','status','operations','seconds','execution'})
            name=row['profile']
            require(name in PROFILES and name not in durations and row['source_revision']==source
                    and row['status']=='PASS' and row['execution']==identity
                    and row['operations']==list(OPERATIONS[name]))
            start,end=interval(by_name['profiles / '+name])
            durations[name]=positive(row['seconds']);require(durations[name]<=end-start+1)
        require(fanin=={'source_revision':source,'status':'PASS','execution':identity,
                       'observed_profile_seconds':durations,'checked_operations':len(LEGACY_OPERATIONS)})
        old_start,old_end=interval(by_name['legacy'])
        require(positive(legacy['seconds'])<=old_end-old_start+1)
        times=[interval(by_name['profiles / '+name]) for name in (*PROFILES,'backend')]
        require(all(type(by_name['profiles / '+n]['runner_id']) is int
                    and by_name['profiles / '+n]['runner_id']>0 for n in PROFILES)
                and len({by_name['profiles / '+n]['runner_id'] for n in PROFILES})==len(PROFILES)
                and times[-1][0]>=max(t[1] for t in times[:-1]))
        return {'schema_version':1,'status':'PASS','source_revision':source,'run_id':run_id,'run_attempt':attempt,
                'same_source_verified':True,'coverage_not_reduced':True,'old_new_equivalent':True,'runner_pool':pool,
                'checked_operations':len(LEGACY_OPERATIONS),'samples_per_arm':1,'performance_gain_asserted':False,
                'coverage_reference_revision':REFERENCE_REVISION,
                'measurements':{
                    'legacy':{'critical_seconds':old_end-old_start,'runner_minutes':round((old_end-old_start)/60,6)},
                    'profiles':{'critical_seconds':max(t[1] for t in times)-min(t[0] for t in times),
                                'runner_minutes':round(sum(t[1]-t[0] for t in times)/60,6)}},
                'scope':'One complete functional pair: original sequential check coverage versus normal parallel backend gate on the same source. Descriptive execution intervals include setup/artifact/fan-in; no p50/p95, causal speed, flake-rate or capacity claim.'}
    except (KeyError,TypeError,AttributeError,IndexError,OverflowError) as error:
        raise ValueError('Incomplete or inconsistent same-source backend shadow') from error
