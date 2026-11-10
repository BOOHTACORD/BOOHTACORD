"""Build an unverified feature sidecar bound to exact native manifest bytes."""
import hashlib
import json
import re

NATIVE = {'windows', 'macos', 'android', 'ios'}
STATES = {'NOT_STARTED', 'PARTIAL', 'IMPLEMENTED', 'UNKNOWN'}


def create_snapshot(catalog, raw_manifest, source_sha, platform, manifest_sha256):
    if (platform not in NATIVE or not re.fullmatch(r'[0-9a-f]{40}', source_sha) or
            not re.fullmatch(r'[0-9a-f]{64}', manifest_sha256) or
            hashlib.sha256(raw_manifest).hexdigest() != manifest_sha256):
        raise ValueError('invalid source, platform or manifest digest')
    try:
        manifest = json.loads(raw_manifest)
        if (type(manifest['schema_version']) is not int or manifest['schema_version'] != 1 or
                manifest['source_revision'] != source_sha or
                manifest['source_dirty'] is not False or manifest['platform'] != platform or
                not isinstance(manifest['version'], str) or not manifest['version'] or
                not isinstance(manifest['release_id'], str) or not manifest['release_id'] or
                not isinstance(manifest['architectures'], list) or not manifest['architectures'] or
                any(not isinstance(a, str) or not a for a in manifest['architectures'])):
            raise ValueError('manifest identity differs from snapshot source')
        features = {}
        for item in catalog['features']:
            identifier = item['id']
            platform_data = item['platforms'][platform]
            revision = platform_data['revision']
            target = item['target_revision']
            if (not isinstance(identifier, str) or not identifier or identifier in features or
                    platform_data['state'] not in STATES or
                    (revision is not None and (type(revision) is not int or revision < 1)) or
                    (target is not None and (type(target) is not int or target < 1)) or
                    (platform_data['state'] == 'IMPLEMENTED' and revision is None)):
                raise ValueError('invalid feature snapshot')
            features[identifier] = {'state': platform_data['state'], 'revision': revision,
                                    'target_revision': target,
                                    'applicability': platform_data['applicability'],
                                    'components': sorted(item['components'])}
    except (KeyError, TypeError, json.JSONDecodeError, UnicodeDecodeError) as error:
        raise ValueError('incomplete manifest or catalog') from error
    return {'schema_version': 1, 'source_revision': source_sha, 'platform': platform,
            'version': manifest['version'], 'release_id': manifest['release_id'],
            'architectures': sorted(manifest['architectures']), 'manifest_sha256': manifest_sha256,
            'features': dict(sorted(features.items())), 'build_provenance': 'UNVERIFIED',
            'published': 'UNKNOWN', 'runtime': 'NOT_VERIFIED'}
