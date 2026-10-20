"""Observe an interrupted SSH client, then independently verify the remote state."""
import json
import signal
import time
from tools.release.delivery.receipt import checked


def checked_failure(value, source, controller):
    value = checked(value)
    if (value['status'] != 'FAIL' or value['source_revision'] != source
            or value['controller_revision'] != controller or not value['phases']
            or value['phases'][-1]['phase'] != 'remote_install'
            or value['phases'][-1]['failure_code'] != 'interrupted'):
        raise ValueError('Exact interrupted remote-install failure is required')
    return value


def idle_lock(root):
    import fcntl
    with (root/'.install.lock').open('a') as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            return False
        fcntl.flock(lock, fcntl.LOCK_UN)
        return True


def exercise(work, report):
    from .positive import attempt, stop, exchange, stable, save
    from tools.qa.compatible_rollback.storage import sql, observe, running
    from tools.release.install.locking import installation_lock
    from tools.release.install.readback import fresh
    source, controller = report['next'], report['controller']
    baseline, images = observe('interruption-guard'), running('interruption-guard')
    progress=dict(status='RUNNING',stage='start',source_revision=source,controller_revision=controller,
                  remote_completion='UNKNOWN')
    report['interruption_diagnostics']=progress
    def checkpoint(stage,**facts):
        progress.update(stage=stage,**facts)
        save(work,report)
    process=None
    deadline = time.monotonic()+180
    try:
        checkpoint('start_client')
        process = attempt(work, 'interrupted', source, controller)
        checkpoint('maintenance_enabled')
        while sql('SELECT active FROM maintenance_admission WHERE singleton=TRUE;') != b't':
            if process.poll() is not None or time.monotonic() > deadline:
                raise RuntimeError('Actual interrupted attempt never reached maintenance')
            time.sleep(.1)
        checkpoint('browser_observation')
        report['observations'].extend(exchange(work, 'interrupted_maintenance', source))
        held=not idle_lock(work/'releases')
        checkpoint('lock_held',lock_observed_held=held)
        if not held:
            raise RuntimeError('Canonical installer did not hold its host lock during maintenance')
        checkpoint('signal_client')
        process.send_signal(signal.SIGTERM)
        code=process.wait(timeout=15)
        checkpoint('client_exit',client_return_code=code)
        if code == 0:
            raise RuntimeError('Interrupted SSH client unexpectedly reported success')
        value=checked(json.loads((work/'attempt-interrupted.json').read_text()))
        checkpoint('delivery_receipt',delivery=value)
        checked_failure(value, source, controller)
        # Closing SSH does not establish whether the server-side command stopped.
        # Never start recovery while its canonical host lock is still held.
        deadline = time.monotonic()+660
        began=time.monotonic()
        checkpoint('idle_lock')
        while not idle_lock(work/'releases'):
            if time.monotonic() > deadline:
                raise TimeoutError('Remote installer lock remains active after client interruption')
            time.sleep(.2)
        checkpoint('idle_lock',lock_observed_idle=True,lock_idle_wait_seconds=round(time.monotonic()-began,6))
        maintenance=sql('SELECT active FROM maintenance_admission WHERE singleton=TRUE;')
        checkpoint('maintenance_disabled',maintenance_active={b't':True,b'f':False}.get(maintenance))
        if maintenance != b'f':
            raise RuntimeError('Interrupted installer left maintenance active; no blind recovery')
        checkpoint('fresh_readback')
        with installation_lock(work/'releases'):
            readback = fresh(work/'releases', source, work/'trusted-signing.pub.pem')
        unchanged=observe('interruption-guard')==baseline and running('interruption-guard')==images
        checkpoint('state_continuity',state_unchanged=unchanged,
                   fresh_readback_health='PASS' if readback['health']=='PASS' else 'FAIL')
        if readback['health'] != 'PASS' or not unchanged:
            raise RuntimeError('Interrupted installation changed data or failed fresh health')
        report['interruption'] = dict(delivery=value, remote_completion='UNKNOWN',
            lock_observed_idle=True, fresh_readback_health='PASS', state_unchanged=True)
        stable(work, report, 'recovered', source)
        report.pop('interruption_diagnostics')
        save(work, report)
    except BaseException as error:
        progress.update(status='FAIL',error_type=type(error).__name__)
        save(work,report)
        raise
    finally:
        if process is not None:stop(process)
