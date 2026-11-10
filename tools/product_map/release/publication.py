"""Check consistency of local records without asserting their authenticity."""
import re
import json

PLATFORMS = {'android', 'windows', 'macos'}


def load_record(path):
    if path.is_symlink() or not path.is_file() or path.stat().st_size > 4_000_000:
        raise ValueError('publication record is missing, too large or a symlink')

    return parse_record(path.read_bytes())


def parse_record(raw):
    if len(raw) > 4_000_000:
        raise ValueError('publication record is too large')

    def pairs(items):
        result = {}
        for key, value in items:
            if key in result:
                raise ValueError(f'duplicate record field: {key}')
            result[key] = value
        return result

    def reject_constant(value):
        raise ValueError(f'invalid JSON constant: {value}')

    return json.loads(raw.decode('utf-8'), object_pairs_hook=pairs,
                      parse_constant=reject_constant)


def match_publication(snapshot, contract, receipt):
    try:
        sha = snapshot['source_revision']
        digest = snapshot['manifest_sha256']
        platform = snapshot['platform']
        identity = contract['identity']
        execution = snapshot['execution']
        version = identity['version']
        build = identity['native_build']
        valid = (
            type(snapshot['schema_version']) is int and snapshot['schema_version'] == 1
            and platform in PLATFORMS and re.fullmatch(r'[0-9a-f]{40}', sha)
            and re.fullmatch(r'[0-9a-f]{64}', digest)
            and re.fullmatch(r'\d+\.\d+\.\d+', version)
            and isinstance(build, str) and re.fullmatch(r'[0-9]+', build)
            and snapshot['version'] == version + '+' + build
            and snapshot['release_id'] == identity['release_id']
            and snapshot['build_provenance'] == 'VERIFIED_ASSET_CONTRACT'
            and snapshot['published'] == 'UNKNOWN' and snapshot['runtime'] == 'NOT_VERIFIED'
            and contract['status'] == 'PASS' and contract['repository'] == 'BOOHTACORD/BOOHTACORD'
            and contract['release_mode'] == 'stable' and contract['tag_verified'] is True
            and contract['source_revision'] == sha and contract['platform'] == platform
            and contract['tag'] == platform + '-v' + version
            and contract['manifest_sha256'] == digest
            and contract['assets']['artifact-manifest.json']['sha256'] == digest
            and receipt['status'] == 'PASS' and receipt['source_revision'] == sha
            and receipt['manifest_sha256'] == digest and receipt['tag'] == contract['tag']
            and type(receipt['release_id']) is int and receipt['release_id'] > 0
            and isinstance(execution, dict) and set(execution) == {'run_id', 'run_attempt'}
            and all(isinstance(execution[k], str) and re.fullmatch(r'[1-9][0-9]*', execution[k])
                    for k in ('run_id', 'run_attempt'))
            and execution == contract['execution'] == receipt['execution']
        )
        if not valid:
            raise ValueError('publication records differ')
    except (KeyError, TypeError, AttributeError) as error:
        raise ValueError('incomplete publication records') from error
    return {'status': 'MATCHED_UNVERIFIED', 'published': 'UNKNOWN',
            'runtime': 'NOT_VERIFIED', 'source_revision': sha,
            'manifest_sha256': digest, 'github_release_id': receipt['release_id']}
