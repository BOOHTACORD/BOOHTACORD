"""Read-only real GitHub artifact transport using the exact shipping downloader."""
import contextlib
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
from tools.release.delivery import authority, download
from tools.release.delivery.consumer import REPOSITORY


def probe(destination, controller):
    if (os.environ.get('GITHUB_REPOSITORY') != REPOSITORY
            or not re.fullmatch('[1-9][0-9]{0,19}', os.environ.get('BUILD_RUN_ID', ''))
            or not re.fullmatch('[a-f0-9]{40}', os.environ.get('REQUESTED_REVISION', ''))
            or not re.fullmatch('[a-f0-9]{40}', controller)):
        raise ValueError('Exact owned producer and controller identities are required')
    destination = Path(destination)
    if not destination.is_absolute() or destination.resolve() != destination:
        raise ValueError('Canonical fresh proof directory is required')
    destination.mkdir(mode=0o700, parents=True, exist_ok=False)
    result = {'status': 'FAIL', 'scope': 'Actual shipping GitHub network downloader; no image execution',
              'controller_revision': controller, 'installation': 'NOT_RUN', 'host_signature': 'NOT_RUN'}
    source = Path(authority.__file__).parent
    result['shipping_module_sha256'] = {name: hashlib.sha256((source/name).read_bytes()).hexdigest()
        for name in ('authority.py', 'preflight.py', 'api.py', 'download.py', 'artifact_download.py', 'artifact_zip.py', 'payload.py')}
    try:
        with contextlib.chdir(destination):
            root = destination/'.out/delivery'
            root.mkdir(parents=True, mode=0o700)
            snapshot = root/'producer.json'
            authority.prepare(snapshot, root/'selected.outputs')
            download.main()
            selected = authority.recheck(snapshot, destination/'.out/incoming')
            observed = json.loads((root/'download.json').read_bytes())
            result['producer'] = {key: selected[key] for key in (
                'id', 'source_revision', 'run_id', 'run_attempt', 'digest', 'size_in_bytes')}
            result['transport'] = {key: observed[key] for key in (
                'outer_digest', 'archive_bytes', 'bundle_sha256', 'bundle_bytes')}
            result['checked_at'] = datetime.now(timezone.utc).isoformat()
            result['status'] = 'PASS'
    finally:
        (destination/'evidence.json').write_text(json.dumps(result, indent=2, sort_keys=True)+'\n')
    return result


def main():
    root = Path(__file__).resolve().parents[3]
    controller = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=root, text=True).strip()
    subprocess.run(['git', 'diff', '--exit-code', 'HEAD', '--'], cwd=root, check=True, capture_output=True)
    try:
        probe(root/'.out/issue395/network', controller)
    except Exception:
        raise SystemExit('Actual downloader proof failed; inspect sanitized evidence.json') from None
    print('PASS: actual exact-producer network download and fresh authority recheck; installation NOT_RUN')


if __name__ == '__main__': main()
