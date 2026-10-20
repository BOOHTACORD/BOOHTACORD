"""Bounded numeric health receipt; never transfer guest log text to the host."""
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import shlex
import subprocess
import tempfile

METRICS = ('free_bytes', 'memory_current', 'memory_max', 'oom', 'oom_kill',
           'cpu_count', 'http_errors', 'socket_errors', 'io_errors', 'no_space_errors')
QUERY = r'''
import json, os
from pathlib import Path
d = {'free_bytes': os.statvfs('/home/runner/actions-runner').f_bavail * os.statvfs('/home/runner/actions-runner').f_frsize,
     'cpu_count': len(os.sched_getaffinity(0))}
for name in ('current', 'max'):
    raw = Path('/sys/fs/cgroup/memory.' + name).read_text().strip()
    if raw.isdecimal(): d['memory_' + name] = int(raw)
for row in Path('/sys/fs/cgroup/memory.events').read_text().splitlines():
    key, value = row.split()
    if key in ('oom', 'oom_kill'): d[key] = int(value)
patterns = {'http_errors': 'HttpRequestException', 'socket_errors': 'SocketException',
            'io_errors': 'IOException', 'no_space_errors': 'No space left on device'}
d.update({key: 0 for key in patterns})
folder = Path('/home/runner/actions-runner/_diag')
for prefix in ('Runner_', 'Worker_'):
    for path in sorted(folder.glob(prefix + '*.log'))[-3:]:
        with path.open('rb') as stream:
            stream.seek(max(0, path.stat().st_size - 131072))
            tail = stream.read(131072).decode(errors='replace')
        for key, pattern in patterns.items(): d[key] += tail.count(pattern)
print(json.dumps(d))
'''


def capture(guest, execute, directory=Path('/opt/boohtacord-ci/health')):
    if guest not in {'boohtacord-ci-' + str(n) for n in range(1, 5)}:
        raise ValueError('Only bounded CI guests can produce health receipts')
    # Guest binaries/output are untrusted. Bound both time and bytes outside
    # the guest; suppress stderr before the byte cap as well.
    args = ['timeout', '15', '/snap/lxd/current/bin/lxc', 'exec', guest,
            '--disable-stdin', '--', 'python3', '-c', QUERY]
    pipeline = shlex.join(args) + ' 2>/dev/null | head -c 8193'
    temporary = None
    try:
        raw = execute(['sh', '-c', pipeline], timeout=20)
        if len(raw.encode()) > 8192:
            return
        data = json.loads(raw)
        if not isinstance(data, dict):
            return
        metrics = {key: data[key] for key in METRICS
                   if key in data and type(data[key]) is int and 0 <= data[key] < 2 ** 63}
        if not metrics:
            return
        directory.mkdir(mode=0o700, parents=True, exist_ok=True)
        receipt = {'observed_at_utc': datetime.now(timezone.utc).isoformat(), 'metrics': metrics,
                   'limit': 'Numeric counters from bounded tails of the latest three Runner/Worker logs; no raw log retention'}
        with tempfile.NamedTemporaryFile(mode='w', dir=directory, delete=False) as stream:
            temporary = Path(stream.name)
            stream.write(json.dumps(receipt) + '\n')
        os.replace(temporary, directory / (guest + '.json'))
    except (OSError, ValueError, subprocess.TimeoutExpired):
        # Observability must not prevent teardown; controller shutdown still propagates.
        return
    finally:
        if temporary is not None:
            try:
                temporary.unlink(missing_ok=True)
            except OSError:
                pass
