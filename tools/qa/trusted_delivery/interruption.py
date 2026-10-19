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
    process = attempt(work, 'interrupted', source, controller)
    deadline = time.monotonic()+180
    try:
        while sql('SELECT active FROM maintenance_admission WHERE singleton=TRUE;') != b't':
            if process.poll() is not None or time.monotonic() > deadline:
                raise RuntimeError('Actual interrupted attempt never reached maintenance')
            time.sleep(.1)
        report['observations'].extend(exchange(work, 'interrupted_maintenance', source))
        if idle_lock(work/'releases'):
            raise RuntimeError('Canonical installer did not hold its host lock during maintenance')
        process.send_signal(signal.SIGTERM)
        if process.wait(timeout=15) == 0:
            raise RuntimeError('Interrupted SSH client unexpectedly reported success')
        value = checked_failure(json.loads((work/'attempt-interrupted.json').read_text()), source, controller)
        # Closing SSH does not establish whether the server-side command stopped.
        # Never start recovery while its canonical host lock is still held.
        deadline = time.monotonic()+660
        while not idle_lock(work/'releases'):
            if time.monotonic() > deadline:
                raise TimeoutError('Remote installer lock remains active after client interruption')
            time.sleep(.2)
        if sql('SELECT active FROM maintenance_admission WHERE singleton=TRUE;') != b'f':
            raise RuntimeError('Interrupted installer left maintenance active; no blind recovery')
        with installation_lock(work/'releases'):
            readback = fresh(work/'releases', source, work/'trusted-signing.pub.pem')
        if (readback['health'] != 'PASS' or observe('interruption-guard') != baseline
                or running('interruption-guard') != images):
            raise RuntimeError('Interrupted installation changed data or failed fresh health')
        report['interruption'] = dict(delivery=value, remote_completion='UNKNOWN',
            lock_observed_idle=True, fresh_readback_health='PASS', state_unchanged=True)
        stable(work, report, 'recovered', source)
        save(work, report)
    finally:
        stop(process)
