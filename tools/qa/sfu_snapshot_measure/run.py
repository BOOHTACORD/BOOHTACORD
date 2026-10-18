"""Measure virtual HTTP observers against real disposable Go/PostgreSQL/LiveKit."""
import argparse
from concurrent.futures import ThreadPoolExecutor
import json
import math
from pathlib import Path
import tempfile
import time
import urllib.error
from tools.qa.client_lifecycle.services import output
from tools.qa.client_lifecycle.stack import ready
from tools.qa.critical_client_acceptance.stack import Stack
from .client import Client
from .identity import api_binary_sha256


def sample(client, workers):
    time.sleep(.4)
    before = client.calls()
    started = time.perf_counter()
    def request(_):
        start = time.perf_counter()
        result = client.request('/voice/participants')
        assert len(result['channels']) == 1
        return (time.perf_counter()-start)*1000
    with ThreadPoolExecutor(max_workers=workers) as executor:
        durations = sorted(executor.map(request, range(workers)))
    elapsed = time.perf_counter()-started
    calls = client.calls()-before
    return {'virtual_http_observers': workers, 'requests': workers, 'room_service_calls': calls,
            'calls_per_second': round(calls/elapsed, 3),
            'http_p95_ms': round(durations[math.ceil(len(durations)*.95)-1], 3),
            'elapsed_seconds': round(elapsed, 3)}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--expect-reduction', action='store_true')
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[3]
    destination = root/'.out/sfu-snapshot-measure'
    destination.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='qa-roster-', dir=root/'.out') as temporary:
        stack = Stack(root, Path(temporary))
        try:
            stack.start()
            client = Client(stack.password)
            category = client.request('/admin/categories', 'POST', {'name': 'SnapshotLab'})
            client.request('/admin/categories/'+category['id']+'/channels', 'POST',
                           {'name': 'SnapshotVoice', 'kind': 'VOICE'})
            samples = [sample(client, count) for count in (1, 20, 100)]
            if args.expect_reduction:
                assert all(item['room_service_calls'] < item['requests']/2 for item in samples[1:])
                client.request('/voice/participants')
                output('docker', 'stop', '-t', '3', stack.owner+'-sfu')
                time.sleep(.4)  # Expire the production 250 ms snapshot before asserting unavailability.
                try:
                    client.request('/voice/participants')
                    raise AssertionError('Expired SFU failure reported a valid roster')
                except urllib.error.HTTPError as error:
                    assert error.code == 503
                output('docker', 'start', stack.owner+'-sfu')
                ready('http://127.0.0.1:4880')
                client.request('/voice/participants')
            else:
                assert all(item['room_service_calls'] >= item['requests'] for item in samples)
            report = {'status': 'PASS', 'actual_api_postgresql_sfu': True, 'samples': samples,
                      'mode': 'bounded' if args.expect_reduction else 'baseline',
                      'same_authorized_session': True, 'media_capacity_claim': False,
                      'sfu_expired_error_recovery_pass': args.expect_reduction,
                      'source_revision': output('git', '-C', str(root), 'rev-parse', 'HEAD'),
                      'api_binary_sha256': api_binary_sha256(stack)}
        finally:
            stack.close()
    report['owned_resources_removed'] = True
    (destination/'report.json').write_text(json.dumps(report, indent=2)+'\n')
    print(json.dumps(report))


if __name__ == '__main__':
    main()
