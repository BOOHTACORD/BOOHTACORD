"""Compare a matched native archive with live release and tag records."""
import re
from datetime import datetime


def match_live_release(evidence, tag, release, tag_commit):
    try:
        sha, digest = evidence['source_revision'], evidence['manifest_sha256']
        inventory, assets = evidence['asset_inventory'], release['assets']
        when = datetime.fromisoformat(release['published_at'].replace('Z', '+00:00'))
        if (evidence['status'] != 'MATCHED_UNVERIFIED' or evidence['published'] != 'UNKNOWN' or
                not re.fullmatch(r'[0-9a-f]{40}', sha) or tag_commit != sha or
                not re.fullmatch(r'[0-9a-f]{64}', digest) or
                type(release['id']) is not int or release['id'] != evidence['github_release_id'] or
                release['tag_name'] != tag or release['target_commitish'] != sha or
                release['draft'] is not False or release['prerelease'] is not False or
                when.tzinfo is None or not isinstance(inventory, dict) or not inventory or
                not isinstance(assets, list) or len(assets) != len(inventory) or len(assets) > 12 or
                inventory['artifact-manifest.json']['sha256'] != digest):
            raise ValueError('release identity differs from native evidence')
        seen = set()
        for asset in assets:
            name = asset['name']
            if name in seen or name not in inventory:
                raise ValueError('release asset set differs')
            expected = inventory[name]
            if (asset['state'] != 'uploaded' or type(asset['size']) is not int or
                    type(expected['bytes']) is not int or not 0 < expected['bytes'] <= 95_000_000 or
                    asset['size'] != expected['bytes'] or
                    not re.fullmatch(r'[0-9a-f]{64}', expected['sha256']) or
                    asset['digest'] != 'sha256:' + expected['sha256']):
                raise ValueError('release asset differs')
            seen.add(name)
    except (KeyError, TypeError, AttributeError, OverflowError) as error:
        raise ValueError('incomplete release metadata') from error
    return {**evidence, 'status': 'LIVE_RELEASE_MATCHED_UNVERIFIED', 'published': 'UNKNOWN'}
