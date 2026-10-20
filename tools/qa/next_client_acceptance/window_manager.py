"""Wait for the owned X11 window manager before exercising visibility changes."""
import re
import subprocess
import time


def has_window_manager(run=subprocess.run):
    try:
        result = run(
            ['xprop', '-root', '_NET_SUPPORTING_WM_CHECK'],
            stdout=subprocess.PIPE,
            text=True,
            timeout=1,
            check=False,
            stderr=subprocess.DEVNULL,
        )
    except (OSError, subprocess.TimeoutExpired):
        return False
    if result.returncode != 0:
        return False
    match = re.search(r'window id # (0x[0-9a-fA-F]+)', result.stdout)
    return bool(match and int(match.group(1), 16) > 0)


def wait_for_window_manager(timeout=10.0, interval=0.1, probe=has_window_manager,
                            sleep=time.sleep, monotonic=time.monotonic):
    if timeout <= 0 or interval <= 0:
        raise ValueError('positive window-manager readiness bounds are required')
    deadline = monotonic() + timeout
    while monotonic() < deadline:
        if probe():
            return
        remaining = deadline - monotonic()
        if remaining > 0:
            sleep(min(interval, remaining))
    raise TimeoutError('X11 window manager did not become ready')


if __name__ == '__main__':
    wait_for_window_manager()
