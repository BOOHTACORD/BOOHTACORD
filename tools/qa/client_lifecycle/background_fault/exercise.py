"""Observe Android Home before pausing exactly one owned dependency."""
import json
import re
import subprocess
import time
import urllib.request

from .owned_pause import pause_owned


def wait_home(runner, device, deadline):
    adb = ['adb', '-s', device]
    home_since = None
    while time.monotonic() < deadline:
        if runner.poll() is not None:
            raise RuntimeError('Native runner exited before fault; inspect its retained log')
        result = subprocess.run(adb+['shell', 'run-as', 'ru.boohtacord.app', 'cat',
            'cache/issue785_flutter_uplink_control.json'], capture_output=True, timeout=10)
        try:
            ready = json.loads(result.stdout).get('status') == 'ready'
        except ValueError:
            ready = False
        activity = subprocess.check_output(adb+['shell', 'dumpsys', 'activity', 'activities'],
                                           text=True, timeout=10)
        home = re.search(r'topResumedActivity=.*(?:nexuslauncher|Launcher)', activity, re.I)
        if ready and home:
            home_since = home_since or time.monotonic()
            if time.monotonic()-home_since >= 5:
                return
        else:
            home_since = None
        time.sleep(1)
    raise RuntimeError('Native publisher never entered measured Home')


def exercise(runner, owner, role, device, deadline, output):
    wait_home(runner, device, deadline)
    url = 'http://127.0.0.1:4820/api/v1/health' if role == 'api' else 'http://127.0.0.1:4880'
    with urllib.request.urlopen(url, timeout=2) as response:
        if response.status != 200:
            raise RuntimeError('Owned dependency did not answer its baseline health probe')
    timeline = None
    try:
        with pause_owned(owner, role) as timeline:
            end = time.monotonic()+{'api': 60, 'sfu': 15}[role]
            try:
                urllib.request.urlopen(url, timeout=1).close()
            except TimeoutError:
                timeline['probe_blocked'] = True
            else:
                raise RuntimeError('Paused dependency did not produce a silent HTTP timeout')
            while time.monotonic() < end:
                if runner.poll() is not None:
                    raise RuntimeError('Native runner failed while dependency was paused')
                time.sleep(max(0, min(1, end-time.monotonic())))
        return timeline
    finally:
        if timeline:
            (output/'fault.json').write_text(json.dumps(timeline, indent=2)+'\n')
