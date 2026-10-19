"""Fresh source-bound readback, including persistent-volume and schema continuity."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import re
from tools.release.bundle.manifest import require
from . import observation
from .docker import verify_running
from .locking import installation_lock
from .state import current_manifest


def collect(directory, manifest):
    verify_running(directory, manifest)
    return {'volumes': observation.volumes(), 'schema_sha256': observation.schema(),
            'sources': observation.sources(manifest['source_revision']), 'health': observation.health(directory)}


def checked(value, source):
    require(isinstance(value, dict) and value.get('health') == 'PASS'
            and value.get('sources') == {'api': source, 'web': source}, 'Installed health or source differs')
    volumes = value.get('volumes')
    require(isinstance(volumes, dict) and set(volumes) == set(observation.VOLUMES)
            and all(isinstance(v, str) and re.fullmatch('[a-f0-9]{64}', v) for v in volumes.values()),
            'Incomplete persistent volume readback')
    require(isinstance(value.get('schema_sha256'), str) and re.fullmatch('[a-f0-9]{64}', value['schema_sha256']),
            'Invalid schema fingerprint')


def record(directory, manifest, previous, before):
    source = manifest['source_revision']
    after = collect(directory, manifest)
    checked(after, source)
    require(before['volumes'] == after['volumes'], 'Persistent volume identity changed during installation')
    same_inventory = previous['compatibility']['migrations'] == manifest['compatibility']['migrations']
    same_schema = before['schema_sha256'] == after['schema_sha256']
    require(not same_inventory or same_schema, 'Schema changed without a migration inventory change')
    inventory = json.dumps(manifest['compatibility']['migrations'], sort_keys=True, separators=(',', ':')).encode()
    result = {'schema_version': 1, 'kind': 'installed-source-readback', 'status': 'PASS',
              'source_revision': source, 'previous_source_revision': previous['source_revision'],
              'persistent_volumes': 'PASS', 'schema_relation': 'unchanged' if same_schema else 'changed-with-migration-inventory',
              'migration_inventory_sha256': hashlib.sha256(inventory).hexdigest(),
              'running_images': {name: item['index_digest'] for name, item in manifest['components'].items()},
              'checked_at': datetime.now(timezone.utc).isoformat(), **after}
    temporary = directory/'deployment-readback.json.tmp'
    temporary.write_text(json.dumps(result, sort_keys=True) + '\n', encoding='utf-8')
    temporary.replace(directory/'deployment-readback.json')
    return result


def fresh(root, revision, public_key):
    require(isinstance(revision, str) and re.fullmatch('[a-f0-9]{40}', revision), 'Invalid readback source')
    manifest = current_manifest(root, public_key)
    require(manifest['source_revision'] == revision, 'Another source is running at readback')
    directory = root/revision
    path = directory/'deployment-readback.json'
    require(not path.is_symlink() and path.is_file() and path.stat().st_nlink == 1
            and 0 < path.stat().st_size <= 16384, 'Installed readback receipt is unavailable')
    receipt = json.loads(path.read_bytes())
    checked(receipt, revision)
    require(receipt.get('schema_version') == 1 and receipt.get('kind') == 'installed-source-readback'
            and receipt.get('status') == 'PASS' and receipt.get('source_revision') == revision
            and receipt.get('persistent_volumes') == 'PASS', 'Installed readback receipt differs')
    after = collect(directory, manifest)
    checked(after, revision)
    require(all(after[key] == receipt[key] for key in ('volumes', 'schema_sha256', 'sources', 'health')),
            'Installed state changed before fresh readback')
    images = {name: item['index_digest'] for name, item in manifest['components'].items()}
    require(images == receipt.get('running_images'), 'Receipt image digests differ from signed manifest')
    return {**receipt, 'checked_at': datetime.now(timezone.utc).isoformat()}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('revision')
    parser.add_argument('--controller-revision', required=True)
    parser.add_argument('--nonce', required=True)
    parser.add_argument('--release-root', type=Path, default=Path('/opt/voice-platform-releases'))
    parser.add_argument('--public-key', type=Path, default=Path('/etc/voice-platform/release-signing.pub.pem'))
    args = parser.parse_args()
    require(re.fullmatch('[a-f0-9]{40}', args.controller_revision) and re.fullmatch('[a-f0-9]{32}', args.nonce),
            'Invalid readback attempt identity')
    with installation_lock(args.release_root):
        value = fresh(args.release_root, args.revision, args.public_key)
        print(json.dumps({**value, 'controller_revision': args.controller_revision, 'nonce': args.nonce}, sort_keys=True))


if __name__ == '__main__': main()
