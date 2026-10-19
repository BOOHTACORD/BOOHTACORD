"""Bound only owned RoomService startup; never retry auth or runtime assertions."""
import math
import re
import subprocess
import time
from tools.release.rollout.livekit_private_path import SAFE_PROBE_CODES

PREFIX = 'LiveKit private path preflight failed: LiveKit private RoomService preflight failed ('
REFUSED = PREFIX + 'roomservice ConnectionRefusedError).'


def safe_failure(text):
    match = re.fullmatch(re.escape(PREFIX) + r'(dns|roomservice|probe|unknown) ([A-Za-z0-9_]+)(?: HTTP ([0-9]{3}))?\)\.', text.strip())
    if match and match[2] in SAFE_PROBE_CODES and (not match[3] or 100 <= int(match[3]) <= 599):
        print(match[0], flush=True)


def wait_roomservice(command, budget=60, runner=subprocess.run, clock=time.monotonic, sleep=time.sleep):
    if type(budget) not in (int, float) or not math.isfinite(budget) or not 0 < budget <= 60:
        raise ValueError('Owned RoomService startup budget must be bounded to 60 seconds')
    started = clock(); attempts = 0; refused = 0
    while True:
        remaining = budget - (clock() - started)
        if remaining <= 0:
            raise TimeoutError('Owned authenticated RoomService did not become ready within its startup budget')
        result = runner(command, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                        timeout=min(10, remaining), check=False)
        attempts += 1
        if result.returncode == 0:
            return {'status':'PASS','attempts':attempts,'elapsed_seconds':round(clock()-started,3),
                    'connection_refused_retries':refused}
        safe_failure(result.stdout)
        if result.returncode != 1 or result.stdout.strip() != REFUSED:
            raise RuntimeError('Owned RoomService rejected a non-transient startup failure')
        refused += 1
        remaining = budget - (clock() - started)
        if remaining <= 0:
            raise TimeoutError('Owned authenticated RoomService did not become ready within its startup budget')
        sleep(min(1, remaining))
