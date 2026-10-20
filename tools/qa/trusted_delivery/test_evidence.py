"""Do not accept partial installations, unrelated failures or private runtime fields."""
from copy import deepcopy
from datetime import datetime,timedelta,timezone
import unittest
from .evidence import validate
from .test_catalog import rows, BASELINE, NEXT
from .test_faults import failed
from tools.qa.compatible_rollback.test_evidence import receipt as rollback_receipt
from tools.release.delivery.test_readback_contract import fixture as acknowledgement
from tools.release.delivery.phases import LIMITS

CONTROLLER = 'c'*40
START=datetime(2026,1,1,tzinfo=timezone.utc)
WINDOW=(START,START+timedelta(minutes=30))
STAMP=START+timedelta(minutes=3)
STABLE = ('baseline','initial','upgraded','retried','recovered','recovery_retried','rolled_back','restored')


def delivery(source, prior, *, stamp=None, nonce=None):
    readback = acknowledgement()
    readback.update(source_revision=source, previous_source_revision=prior, controller_revision=CONTROLLER,
                    sources={'api': source, 'web': source},running_images=dict.fromkeys(('api','web'),'sha256:'+'f'*64))
    if stamp is not None:readback['checked_at']=stamp.isoformat()
    if nonce is not None:readback['nonce']=nonce
    return dict(schema_version=1, kind='delivery-phases', source_revision=source,
        controller_revision=CONTROLLER, status='PASS', readback=readback,
        phases=[dict(phase=p,limit_seconds=n,status='PASS',failure_code=None,exit_code=None,elapsed_seconds=.1)
                for p,n in LIMITS.items()])


def receipt():
    template = rollback_receipt()
    storage, running = [], []
    for phase in STABLE:
        snapshot = deepcopy(template['storage'][0]); snapshot['phase'] = phase; storage.append(snapshot)
        state = deepcopy(template['running'][0]); state['phase'] = phase
        state['revision'] = BASELINE if phase in ('baseline','initial','rolled_back') else NEXT
        running.append(state)
    interrupted = failed('remote_install','interrupted')
    interrupted.update(source_revision=NEXT,controller_revision=CONTROLLER)
    installations=[]
    for name,source,prior in [('initial',BASELINE,BASELINE),('upgrade',NEXT,BASELINE),
                              ('retry',NEXT,NEXT),('recovery-retry',NEXT,NEXT)]:
        nonce=f'{len(installations)+1:032x}'
        installations.append(dict(name=name,delivery=delivery(source,prior,stamp=STAMP,nonce=nonce),
            attempt_nonce=nonce,acknowledged_at=(STAMP+timedelta(seconds=1)).isoformat(),observed_seconds=20,
            maintenance_observed_seconds=15,maintenance_enable_uncertainty_seconds=.1,
            maintenance_disable_uncertainty_seconds=.1,
            scope='Polling observations, not exact enable/disable timestamps; signed runtime may be legacy'))
    transport=[]
    for name,phase,code in [('ssh-refused','current_revision','exit'),('scp-timeout','transfer_bundle','timeout'),
                             ('immutable','remote_install','exit'),('downgrade','history','exit')]:
        result=failed(phase,code); result.update(source_revision=BASELINE if name=='downgrade' else NEXT,controller_revision=CONTROLLER)
        transport.append(dict(name=name,status='EXPECTED_FAIL',delivery=result,state_unchanged=True,
            fault='real bandwidth-limited SCP with one-second local deadline' if name=='scp-timeout' else name))
    return dict(status='PASS',scope='isolated-real-stack',baseline=BASELINE,next=NEXT,controller=CONTROLLER,
        observations=rows(),storage=storage,running=running,installations=installations,
        rollback_preflight=template['preflight'],qa_operator_approval='OWNED_QA_ONLY_USER_REQUESTED',
        interruption=dict(delivery=interrupted,remote_completion='UNKNOWN',lock_observed_idle=True,
                          fresh_readback_health='PASS',state_unchanged=True),
        negatives=dict(status='PASS',transport=transport,health_readback=dict(health_failure='EXPECTED_FAIL',
            fresh_ack_failure='EXPECTED_FAIL',health_restored='PASS',installed_receipt_unchanged=True,
            foreign_nonce='EXPECTED_FAIL',scope='Actual paused QA API and HTTPS probe; no failed rollout or production outage claimed'),
            scope='Owned real failures; no production mutation or claim that interrupting SSH stops remote Docker'))


class EvidenceTests(unittest.TestCase):
    def test_recorded_ack_freshness_uses_actual_receipt_time_and_trusted_execution_window(self):
        from tools.release.delivery.receipt import checked
        value=receipt()
        # A valid historical proof must never become a fresh production ACK now.
        with self.assertRaises(ValueError):checked(value['installations'][0]['delivery'])
        validate(value,window=WINDOW)
        for mode in ('stale_at_receipt','future_at_receipt','outside_window','nonce','reused_nonce'):
            value=receipt();row=value['installations'][0]
            if mode=='stale_at_receipt':row['acknowledged_at']=(STAMP+timedelta(seconds=301)).isoformat()
            if mode=='future_at_receipt':row['acknowledged_at']=(STAMP-timedelta(seconds=31)).isoformat()
            if mode=='outside_window':row['acknowledged_at']=(START-timedelta(seconds=1)).isoformat()
            if mode=='nonce':row['attempt_nonce']='0'*32
            if mode=='reused_nonce':
                later=value['installations'][3];later['attempt_nonce']=row['attempt_nonce']
                later['delivery']['readback']['nonce']=row['attempt_nonce']
            with self.subTest(mode=mode),self.assertRaises(ValueError):validate(value,window=WINDOW)
        with self.assertRaises(ValueError):validate(receipt())

    def test_complete_actual_install_retry_interruption_rollback_and_failures_are_required(self):
        validate(receipt(),window=WINDOW)
        for mode in ('observation','storage','running','install','retry','negative','health','source','controller',
                     'approval','scope','private','remote_claim','busy_lock','interrupt_phase','drift','image','nan'):
            value=receipt()
            if mode=='observation':value['observations'].pop()
            if mode=='storage':value['storage'].pop()
            if mode=='running':value['running'][1]=deepcopy(value['running'][0])
            if mode=='install':value['installations'].pop()
            if mode=='retry':value['installations'][2]['delivery']['readback']['previous_source_revision']=BASELINE
            if mode=='negative':value['negatives']['transport'].pop()
            if mode=='health':value['negatives']['health_readback']['health_restored']='FAIL'
            if mode=='source':value['installations'][1]['delivery']['source_revision']=BASELINE
            if mode=='controller':value['installations'][0]['delivery']['controller_revision']='d'*40
            if mode=='approval':value['qa_operator_approval']='PRODUCTION_APPROVED'
            if mode=='scope':value['scope']='production'
            if mode=='private':value['storage'][0]['cookie']='forbidden'
            if mode=='remote_claim':value['interruption']['remote_completion']='STOPPED'
            if mode=='busy_lock':value['interruption']['lock_observed_idle']=False
            if mode=='interrupt_phase':value['interruption']['delivery']=failed('transfer_bundle','interrupted')
            if mode=='drift':value['storage'][2]['content']['database']='0'*64
            if mode=='image':value['running'][2]['images']['api']['configured']='voice-platform-api:mutable'
            if mode=='nan':value['installations'][0]['observed_seconds']=float('nan')
            with self.subTest(mode=mode),self.assertRaises(ValueError):validate(value,window=WINDOW)
