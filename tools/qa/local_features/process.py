"""Bounded native commands; stop their owned process group on failure to finish."""
import os
import signal
import subprocess
import time


def stop_group(process):
    try:os.killpg(process.pid,signal.SIGTERM)
    except ProcessLookupError:pass
    deadline=time.monotonic()+5
    while time.monotonic()<deadline:
        process.poll()
        try:os.killpg(process.pid,0)
        except ProcessLookupError:break
        time.sleep(.05)
    try:os.killpg(process.pid,signal.SIGKILL)
    except ProcessLookupError:pass
    process.wait()


def run_owned(command, *, timeout, **options):
    process=subprocess.Popen(command,start_new_session=True,**options)
    try:
        code=process.wait(timeout=timeout)
    except (subprocess.TimeoutExpired,KeyboardInterrupt):
        stop_group(process)
        raise
    if code:raise subprocess.CalledProcessError(code,command)
