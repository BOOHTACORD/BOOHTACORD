"""Observe real shipping SSH installations and the approved QA-only rollback CLI."""
import json
import os
from pathlib import Path
import secrets
import shutil
import subprocess
import time
from tools.qa.compatible_rollback.storage import observe, running, sql
from tools.release.delivery.receipt import checked
from tools.release.rollback.preflight import preflight
from .catalog import validate_observations
from .variant import transport


def exchange(work, phase, revision):
    # The existing Linux fixture places its bare support modules on /qa-tools.
    from tools.qa.compatible_rollback.rehearse import exchange as observed_exchange
    return observed_exchange(work,phase,revision)


def save(work, report):
    (work/'delivery-runtime.json').write_text(json.dumps(report,indent=2,sort_keys=True)+'\n')


def attempt(work, name, source, controller, *, archive=None):
    directory=work/'private/incoming'/name; directory.mkdir(mode=0o700,parents=True)
    archive=archive or work/'releases'/(source+'.release.tar.gz')
    if not archive.is_file(): archive=transport(work/'releases'/source,source)
    for path in (archive,archive.parent/(archive.name+'.sha256')): shutil.copyfile(path,directory/path.name)
    plan={'source':source,'controller':controller,'nonce':secrets.token_hex(16)}
    (work/'private'/('attempt-'+name+'.json')).write_text(json.dumps(plan))
    with (work/'private'/('attempt-'+name+'.log')).open('wb') as log:
        return subprocess.Popen(['python3','-m','tools.qa.trusted_delivery.attempt',name],cwd='/qa/controller',
                                env=dict(os.environ,PYTHONPATH='/qa-builder:/qa-tools'),stdout=log,stderr=subprocess.STDOUT)


def stop(process):
    if process.poll() is None:
        process.terminate()
        try: process.wait(timeout=10)
        except subprocess.TimeoutExpired: process.kill(); process.wait(timeout=5)


def stable(work, report, phase, revision):
    state=running(phase)
    if state['revision']!=revision: raise RuntimeError('Actual running source differs')
    report['observations'].extend(exchange(work,phase,revision))
    report['storage'].append(observe(phase)); report['running'].append(state)
    for row in report['storage'][1:]:
        if any(row[key]!=report['storage'][0][key] for key in ('volumes','networks','content')):
            raise RuntimeError('Persistent identity, schema or synthetic committed data changed')
    save(work,report)


def install(work, report, name, before, after, warning, complete):
    if sql('SELECT active FROM maintenance_admission WHERE singleton=TRUE;')!=b'f':
        raise RuntimeError('Owned installation must begin outside maintenance')
    began=time.monotonic(); enabled=None; disabled=None; last_inactive=began; last_active=None
    process=attempt(work,name,after,report['controller'])
    try:
        while time.monotonic()-began<900:
            active=sql('SELECT active FROM maintenance_admission WHERE singleton=TRUE;')==b't'
            observed=time.monotonic()
            if active: last_active=observed
            if active and enabled is None:
                enabled=observed
                report['observations'].extend(exchange(work,warning,before)); save(work,report)
            elif not active and enabled is None: last_inactive=observed
            elif not active and disabled is None: disabled=observed
            if process.poll() is not None:
                if process.returncode or active or enabled is None:
                    raise RuntimeError('Actual installer failed or maintenance boundary was not observed')
                result=checked(json.loads((work/('attempt-'+name+'.json')).read_text()))
                if (result['source_revision']!=after or result['readback']['previous_source_revision']!=before
                        or result['controller_revision']!=report['controller']):
                    raise RuntimeError('Actual transfer acknowledgement differs')
                report['installations'].append({'name':name,'delivery':result,'observed_seconds':round(observed-began,6),
                    'maintenance_observed_seconds':round(disabled-enabled,6),
                    'maintenance_enable_uncertainty_seconds':round(enabled-last_inactive,6),
                    'maintenance_disable_uncertainty_seconds':round(disabled-last_active,6),
                    'scope':'Polling observations, not exact enable/disable timestamps; signed runtime may be legacy'})
                stable(work,report,complete,after)
                return
            time.sleep(.1)
        raise TimeoutError('Owned installation observation exceeded its bound')
    finally: stop(process)


def rollback(work, report):
    before=observe('guard'); images=running('guard')
    preflight(work/'releases',report['next'],report['baseline'],work/'trusted-signing.pub.pem')
    if before!=observe('guard') or images!=running('guard'):
        raise RuntimeError('Read-only rollback preflight mutated the live stack')
    report['rollback_preflight']=dict.fromkeys(('read_only','signed_bundles','digest_only','compatible'),True)
    report['qa_operator_approval']='OWNED_QA_ONLY_USER_REQUESTED'
    with (work/'private/rollback.log').open('wb') as log:
        process=subprocess.Popen(['python3','-m','tools.release.rollback.run',report['next'],report['baseline'],
                                  '--rehearse','--observe-seconds','90'],cwd='/qa/controller',
                                 env=dict(os.environ,PYTHONPATH='/qa-builder:/qa-tools'),stdout=log,stderr=subprocess.STDOUT)
    seen=set(); deadline=time.monotonic()+900
    try:
        while time.monotonic()<deadline:
            active=sql('SELECT active FROM maintenance_admission WHERE singleton=TRUE;')==b't'
            try: source=running('probe')['revision']
            except (ValueError,KeyError,subprocess.CalledProcessError): source=None
            phase=None
            if active and 'rollback_maintenance' not in seen: phase='rollback_maintenance'
            elif source==report['baseline'] and not active and 'rolled_back' not in seen: phase='rolled_back'
            elif active and 'rolled_back' in seen and 'restore_maintenance' not in seen: phase='restore_maintenance'
            elif source==report['next'] and not active and 'restore_maintenance' in seen and 'restored' not in seen: phase='restored'
            if phase:
                revision=report['baseline'] if phase in ('rolled_back','restore_maintenance') else report['next']
                if phase.endswith('_maintenance'): report['observations'].extend(exchange(work,phase,revision))
                else: stable(work,report,phase,revision)
                seen.add(phase); save(work,report)
            if process.poll() is not None:
                if process.returncode or seen!={'rollback_maintenance','rolled_back','restore_maintenance','restored'}:
                    raise RuntimeError('Canonical rollback/recovery did not complete every observed boundary')
                return
            time.sleep(.1)
        raise TimeoutError('Owned canonical rollback exceeded its bound')
    finally: stop(process)


def run(work):
    configuration=json.loads((work/'private/browser.json').read_text())
    controller=subprocess.check_output(['git','rev-parse','HEAD'],cwd='/qa/controller',text=True).strip()
    report={'status':'RUNNING','scope':'isolated-real-stack','baseline':configuration['current'],'next':configuration['previous'],
            'controller':controller,'observations':[],'storage':[],'running':[],'installations':[]}
    save(work,report)
    try:
        stable(work,report,'baseline',report['baseline'])
        install(work,report,'initial',report['baseline'],report['baseline'],'initial_maintenance','initial')
        install(work,report,'upgrade',report['baseline'],report['next'],'upgrade_maintenance','upgraded')
        install(work,report,'retry',report['next'],report['next'],'retry_maintenance','retried')
        from .interruption import exercise
        exercise(work,report)
        install(work,report,'recovery-retry',report['next'],report['next'],'recovery_retry_maintenance','recovery_retried')
        rollback(work,report)
        validate_observations(report['observations'],report['baseline'],report['next'])
        report['status']='PASS'
        return report
    finally:
        if report['status']!='PASS': report['status']='FAIL'
        save(work,report)
