"""Read-only API baseline for one isolated deployment; does not generate media."""
import argparse
import concurrent.futures
import json
import os
import threading
import time
import uuid
from pathlib import Path

from tools.qa.backend_load.client import ApiClient
from tools.qa.backend_load.metrics import Metrics
from tools.qa.backend_load.safety import CONFIRMATION, validate_run


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--target', required=True, help='isolated API origin')
    parser.add_argument('--accounts', required=True, help='private JSON synthetic account file')
    parser.add_argument('--channel-id', required=True, help='seeded TEXT channel UUID')
    parser.add_argument('--query', default='loadtest')
    parser.add_argument('--vus', type=int, default=1)
    parser.add_argument('--duration-seconds', type=int, default=30)
    parser.add_argument('--ramp-seconds', type=int, default=10)
    parser.add_argument('--confirm', default='', help='must equal ' + CONFIRMATION)
    parser.add_argument('--report', required=True, help='write aggregate JSON outside the repo')
    args = parser.parse_args()
    accounts = json.loads(Path(args.accounts).read_text(encoding='utf-8'))['accounts']
    validate_run(args.target, args.vus, len(accounts), args.confirm)
    if any(not isinstance(account, dict) or set(account) != {'login', 'password'}
           for account in accounts):
        parser.error('accounts must contain only synthetic login and password fields')
    if len({account['login'] for account in accounts}) != len(accounts):
        parser.error('each VU must use a distinct synthetic account')
    try:
        channel_id = str(uuid.UUID(args.channel_id))
    except ValueError:
        parser.error('channel-id must be a UUID from the isolated test dataset')
    if not 1 <= args.duration_seconds <= 300 or not 0 <= args.ramp_seconds <= 300:
        parser.error('duration and ramp must be between 0 and 300 seconds')
    metrics, lock = Metrics(), threading.Lock()
    stop_at = time.monotonic() + args.duration_seconds
    def worker(index):
        time.sleep(args.ramp_seconds * index / max(args.vus - 1, 1))
        client = ApiClient(args.target, accounts[index], 5)
        login = client.login()
        with lock:
            metrics.record(login)
        while time.monotonic() < stop_at:
            results = client.read_cycle(channel_id, args.query)
            with lock:
                for result in results:
                    metrics.record(result)
            time.sleep(.05)
    with concurrent.futures.ThreadPoolExecutor(max_workers=args.vus) as pool:
        list(pool.map(worker, range(args.vus)))
    report = {'schema_version': 1, 'status': 'RUN_COMPLETED_NOT_CAPACITY_EVIDENCE',
              'profile': {'vus': args.vus, 'duration_seconds': args.duration_seconds,
                          'ramp_seconds': args.ramp_seconds},
              'operations': metrics.report()}
    destination = Path(args.report)
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
    os.chmod(destination, 0o600)
    print('aggregate report written; credentials and response bodies were not recorded')


if __name__ == '__main__':
    main()
