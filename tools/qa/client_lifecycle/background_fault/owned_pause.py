"""Bound a silent dependency fault to this run's local, labeled QA container."""
from contextlib import contextmanager
import re
import subprocess
import time

from tools.qa.client_lifecycle.services import LABEL, local_docker


def _run(*args):
    return subprocess.check_output(args, text=True, timeout=15).strip()


@contextmanager
def pause_owned(owner, role, *, invoke=_run, check_local=local_docker):
    if not re.fullmatch(r'qa-client-[0-9a-f]{16}', owner) or role not in ('api', 'sfu'):
        raise ValueError('Only this QA run API or SFU can be paused')
    check_local()
    name = owner + '-' + role

    def state():
        label = invoke('docker', 'inspect', '--format', '{{index .Config.Labels "'+LABEL+'"}}', name)
        if label != owner:
            raise ValueError('Refusing to change a foreign container')
        return invoke('docker', 'inspect', '--format', '{{.State.Running}} {{.State.Paused}}', name)

    if state() != 'true false':
        raise ValueError('Owned container must be running and initially unpaused')
    timeline = {'owner': owner, 'role': role, 'pause_verified': False, 'restore_verified': False}
    started = time.monotonic()
    timeline['pause_requested_unix_ms'] = int(time.time() * 1000)
    try:
        invoke('docker', 'pause', name)
        if state() != 'true true':
            raise RuntimeError('Owned container did not enter the paused state')
        timeline['pause_verified'] = True
        timeline['pause_verified_unix_ms'] = int(time.time() * 1000)
        yield timeline
    finally:
        timeline['restore_requested_unix_ms'] = int(time.time() * 1000)
        if state() == 'true true':
            invoke('docker', 'unpause', name)
        if state() != 'true false':
            raise RuntimeError('Owned container did not return to running state')
        timeline['restore_verified'] = True
        timeline['restore_verified_unix_ms'] = int(time.time() * 1000)
        timeline['duration_seconds'] = round(time.monotonic() - started, 3)
