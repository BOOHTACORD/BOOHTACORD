"""Exact public live-delivery evidence; incomplete or unrelated proofs stay red."""
import math
from tools.qa.compatible_rollback.evidence import digest, require
from tools.release.delivery.receipt import checked
from .catalog import validate_observations
from .interruption import checked_failure
from .faults import EXPECTED, require_failure
from .historical_delivery import checked as recorded,execution_window

STABLE = ('baseline','initial','upgraded','retried','recovered','recovery_retried','rolled_back','restored')


def validate(value, *, window=None):
    try:
        check(value,execution_window(window))
    except (KeyError, TypeError, AttributeError, IndexError, OverflowError):
        raise ValueError('Incomplete public real-installation evidence') from None


def check(value,window):
    require(set(value)=={'status','scope','baseline','next','controller','observations','storage','running',
        'installations','rollback_preflight','qa_operator_approval','interruption','negatives'})
    require(value['status']=='PASS' and value['scope']=='isolated-real-stack'
            and value['qa_operator_approval']=='OWNED_QA_ONLY_USER_REQUESTED')
    baseline,newer,controller=(value[k] for k in ('baseline','next','controller'))
    require(all(digest(s,40) for s in (baseline,newer,controller)) and baseline!=newer)
    validate_observations(value['observations'],baseline,newer)
    require(value['rollback_preflight']==dict.fromkeys(('read_only','signed_bundles','digest_only','compatible'),True)
            and all(v is True for v in value['rollback_preflight'].values()))
    storage,running=value['storage'],value['running']
    require([r['phase'] for r in storage]==list(STABLE) and [r['phase'] for r in running]==list(STABLE))
    state_by_source={}
    for snapshot,state in zip(storage,running):
        require(set(snapshot)=={'phase','volumes','networks','content'})
        for key,expected in [('volumes',{'postgres-data','attachments-data','caddy-data','caddy-config'}),
                ('networks',{'edge','private','sfu-egress'}),('content',{'database','attachments','tls','proxy_config','schema'})]:
            require(set(snapshot[key])==expected and all(digest(v) for v in snapshot[key].values())
                    and snapshot[key]==storage[0][key])
        source=baseline if state['phase'] in ('baseline','initial','rolled_back') else newer
        require(set(state)=={'phase','revision','images'} and state['revision']==source
                and set(state['images'])=={'api','web'})
        for service,image in state['images'].items():
            require(set(image)=={'configured','running'} and isinstance(image['running'],str)
                    and image['running'].startswith('sha256:') and digest(image['running'][7:])
                    and image['configured']=='voice-platform-'+service+'@'+image['running'])
        if source in state_by_source:require(state_by_source[source]==state['images'])
        else:state_by_source[source]=state['images']
    expected=[('initial',baseline,baseline),('upgrade',newer,baseline),('retry',newer,newer),('recovery-retry',newer,newer)]
    require(len(value['installations'])==len(expected))
    nonces=set()
    for row,(name,source,prior) in zip(value['installations'],expected):
        require(set(row)=={'name','delivery','attempt_nonce','acknowledged_at','observed_seconds','maintenance_observed_seconds',
            'maintenance_enable_uncertainty_seconds','maintenance_disable_uncertainty_seconds','scope'})
        require(row['name']==name and row['scope']=='Polling observations, not exact enable/disable timestamps; signed runtime may be legacy')
        receipt=recorded(row['delivery'],nonce=row['attempt_nonce'],observed_at=row['acknowledged_at'],window=window)
        require(row['attempt_nonce'] not in nonces)
        nonces.add(row['attempt_nonce'])
        require(receipt['status']=='PASS' and receipt['source_revision']==source
                and receipt['controller_revision']==controller and receipt['readback']['previous_source_revision']==prior
                and receipt['readback']['running_images']=={s:i['running'] for s,i in state_by_source[source].items()})
        for key in ('observed_seconds','maintenance_observed_seconds','maintenance_enable_uncertainty_seconds','maintenance_disable_uncertainty_seconds'):
            require(type(row[key]) in (int,float) and math.isfinite(row[key]) and 0<=row[key]<=1800)
        require(0<row['maintenance_observed_seconds']<=row['observed_seconds'])
    interruption=value['interruption']
    require(set(interruption)=={'delivery','remote_completion','lock_observed_idle','fresh_readback_health','state_unchanged'}
        and interruption['remote_completion']=='UNKNOWN' and interruption['lock_observed_idle'] is True
        and interruption['fresh_readback_health']=='PASS' and interruption['state_unchanged'] is True)
    checked_failure(interruption['delivery'],newer,controller)
    negative=value['negatives']
    require(set(negative)=={'status','transport','health_readback','scope'} and negative['status']=='PASS'
        and negative['scope']=='Owned real failures; no production mutation or claim that interrupting SSH stops remote Docker'
        and [r['name'] for r in negative['transport']]==list(EXPECTED))
    for row in negative['transport']:
        name=row['name']; receipt=checked(row['delivery']); require_failure(name,receipt)
        require(set(row)=={'name','status','delivery','state_unchanged','fault'} and row['status']=='EXPECTED_FAIL'
            and row['state_unchanged'] is True and receipt['source_revision']==(baseline if name=='downgrade' else newer)
            and receipt['controller_revision']==controller and row['fault']==(
                'real bandwidth-limited SCP with one-second local deadline' if name=='scp-timeout' else name))
    health=negative['health_readback']
    require(health==dict(health_failure='EXPECTED_FAIL',fresh_ack_failure='EXPECTED_FAIL',health_restored='PASS',
        installed_receipt_unchanged=True,foreign_nonce='EXPECTED_FAIL',
        scope='Actual paused QA API and HTTPS probe; no failed rollout or production outage claimed')
        and health['installed_receipt_unchanged'] is True)
