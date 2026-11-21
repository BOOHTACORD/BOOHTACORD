"""Bounded child process; a timeout removes only the process tree we started."""
import os
import subprocess
from tools.qa.local_features.process import stop_group


def run_native(command, **options):
    flags = dict(creationflags=subprocess.CREATE_NEW_PROCESS_GROUP) if os.name == 'nt' else dict(start_new_session=True)
    process = subprocess.Popen(command, **flags, **options)
    try:
        code = process.wait(timeout=1200)
    except (subprocess.TimeoutExpired, KeyboardInterrupt):
        if process.poll() is None:
            if os.name == 'nt':
                subprocess.run(['taskkill', '/PID', str(process.pid), '/T', '/F'],
                               check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                process.wait()
            else:
                stop_group(process)
        raise
    if code: raise subprocess.CalledProcessError(code, command)
