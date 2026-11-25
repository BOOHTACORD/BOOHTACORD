"""Actual clipboard/UI and capacity reservation checks; no production account or disk fill."""
import json
import os
import re
import signal
import subprocess
import tempfile
import time
from pathlib import Path
from tools.qa.upload_reservations.client import Client
from tools.qa.upload_reservations.measure import await_reserved, sample
from tools.qa.upload_reservations.stack import UploadStack


def main():
    root = Path(__file__).resolve().parents[3]
    destination = root / '.out/clipboard-paste'
    destination.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='private-', dir=destination) as private:
        work = Path(private)
        stack, process, held = UploadStack(root, work, 2147483648+51000000), None, []
        try:
            stack.start()
            client = Client(stack.password)
            payload = work / 'input.json'
            payload.write_text(json.dumps({'password': stack.password, 'private': private, 'directory': str(destination)}))
            payload.chmod(0o600)
            environment = dict(os.environ, QA_ORIGIN='https://localhost:4810', QA_INPUT=str(payload),
                               QA_RESULT=str(destination/'result.json'))
            process = subprocess.Popen(['xvfb-run', '-a', 'node', 'tools/qa/clipboard_paste/scenario.mjs'],
                                       cwd=root, env=environment, start_new_session=True)
            completed, admission, deadline = set(), {}, time.monotonic()+420
            while process.poll() is None:
                if time.monotonic() > deadline:
                    raise TimeoutError('Owned clipboard acceptance exceeded its finite budget')
                for width in (1440, 393):
                    for phase in ('arm', 'release', 'pending', 'cancelled'):
                        name = f'{phase}-{width}'
                        request = work / (name+'.json')
                        if name in completed or not request.exists():
                            continue
                        if phase == 'arm':
                            channel = json.loads(request.read_text())['channel']
                            assert re.fullmatch(r'[a-f0-9-]{36}', channel)
                            held = [client.upload(channel), client.upload(channel)]
                            await_reserved(stack, 50000000, [])
                        elif phase == 'release':
                            for connection in held:
                                connection.close()
                            held.clear()
                            await_reserved(stack, 0, [])
                        elif phase == 'pending':
                            reserved = sample(stack)['reserved']
                            assert reserved in (0, 25000000), 'Unexpected concurrent upload admission'
                            admission[str(width)] = reserved
                        else:
                            await_reserved(stack, 0, [])
                        completed.add(name)
                        (work/(name+'.ready')).touch(mode=0o600)
                time.sleep(.05)
            assert process.returncode == 0, 'Owned clipboard browser acceptance failed'
            assert len(completed) == 8, 'Actual capacity/cancellation phases were not all observed'
            result = json.loads((destination/'result.json').read_text())
            result['pending_upload_reserved_bytes'] = admission
        finally:
            if process and process.poll() is None:
                os.killpg(process.pid, signal.SIGTERM)
                process.wait(timeout=10)
            for connection in held:
                connection.close()
            stack.close()
    result['owned_resources_removed'] = True
    (destination/'result.json').write_text(json.dumps(result, indent=2)+'\n')
    print('Actual TEXT clipboard, storage507/retry and scope cancellation PASS; owned resources removed')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
