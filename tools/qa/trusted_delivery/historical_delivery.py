"""Audit an ACK already checked live; never accept it as a fresh install response."""
from datetime import datetime,timedelta
import math
import re
from tools.release.delivery.phases import LIMITS
from tools.release.delivery.readback_contract import KEYS,VOLUMES
from tools.release.install.timings import validate as rollout_timings


def require(value):
    if not value:raise ValueError('Incomplete recorded delivery evidence')


def date(value):
    require(isinstance(value,str) and len(value)<=64)
    try:result=datetime.fromisoformat(value)
    except ValueError:raise ValueError('Invalid recorded delivery time') from None
    require(result.tzinfo is not None and result.utcoffset()==timedelta(0))
    return result


def execution_window(window):
    require(isinstance(window,tuple) and len(window)==2)
    start,end=window
    require(all(isinstance(v,datetime) and v.tzinfo is not None and v.utcoffset()==timedelta(0) for v in window)
            and 0<=(end-start).total_seconds()<=3600)
    return start,end


def digest(value,size):
    return isinstance(value,str) and re.fullmatch('[0-9a-f]{'+str(size)+'}',value) is not None


def checked(value, *, nonce, observed_at, window):
    # This separate QA reader uses the immutable recorded receipt time, bounded
    # by the caller's trusted execution window. It never patches the production
    # validator, clock or original payload. Production ACKs still expire at 300s.
    start,end=execution_window(window)
    observed=date(observed_at)
    require(start<=observed<=end and digest(nonce,32))
    require(set(value)=={'schema_version','kind','source_revision','controller_revision','status','phases','readback'}
            and type(value['schema_version']) is int and value['schema_version']==1
            and value['kind']=='delivery-phases' and value['status']=='PASS')
    source,controller=value['source_revision'],value['controller_revision']
    require(digest(source,40) and digest(controller,40) and len(value['phases'])==len(LIMITS))
    for row,(phase,limit) in zip(value['phases'],LIMITS.items()):
        require(set(row)=={'phase','limit_seconds','status','failure_code','exit_code','elapsed_seconds'}
                and row['phase']==phase and type(row['limit_seconds']) is int and row['limit_seconds']==limit
                and row['status']=='PASS' and row['failure_code'] is None and row['exit_code'] is None)
        elapsed=row['elapsed_seconds']
        require(type(elapsed) in (int,float) and math.isfinite(elapsed) and 0<=elapsed<=1800)
    ack=value['readback']
    require(set(ack) in (KEYS,KEYS|{'rollout'}) and type(ack['schema_version']) is int and ack['schema_version']==1)
    expected=dict(kind='installed-source-readback',status='PASS',source_revision=source,controller_revision=controller,
                  nonce=nonce,persistent_volumes='PASS',health='PASS',sources={'api':source,'web':source})
    require(all(ack[key]==item for key,item in expected.items()) and digest(ack['previous_source_revision'],40)
            and ack['schema_relation'] in ('unchanged','changed-with-migration-inventory'))
    require(all(digest(ack[key],64) for key in ('schema_sha256','migration_inventory_sha256')))
    for key,names,pattern in [('volumes',set(VOLUMES),'[0-9a-f]{64}'),
                             ('running_images',{'api','web'},'sha256:[0-9a-f]{64}')]:
        require(isinstance(ack[key],dict) and set(ack[key])==names
                and all(isinstance(v,str) and re.fullmatch(pattern,v) for v in ack[key].values()))
    require(-30<=(observed-date(ack['checked_at'])).total_seconds()<=300)
    if 'rollout' in ack:rollout_timings(ack['rollout'])
    return value
