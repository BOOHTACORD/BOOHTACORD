"""Select a candidate artifact; callers must authenticate API and bytes."""
import re

REPOSITORY = 'BOOHTACORD/BOOHTACORD'
PLATFORMS = {'windows', 'macos', 'android'}


def _positive(value):
    return type(value) is int and value > 0


def select_native_artifact(run, document, platform, run_id, tag):
    try:
        if (platform not in PLATFORMS or not _positive(run_id) or
                not re.fullmatch(re.escape(platform) + r'-v\d+\.\d+\.\d+', tag)):
            raise ValueError('invalid native release identity')
        sha, attempt = run['head_sha'], run['run_attempt']
        repo, head = run['repository'], run['head_repository']
        branch, event = run['head_branch'], run['event']
        valid_ref = (event == 'push' and branch == tag) or (
            event == 'workflow_dispatch' and branch == 'master')
        if (not re.fullmatch(r'[0-9a-f]{40}', sha) or not _positive(attempt) or
                run['id'] != run_id or type(run['id']) is not int or
                repo['full_name'] != REPOSITORY or head['full_name'] != REPOSITORY or
                not _positive(repo['id']) or not _positive(head['id']) or head['id'] != repo['id'] or
                run['path'] != f'.github/workflows/{platform}-release.yaml' or
                not valid_ref or run['status'] != 'completed' or run['conclusion'] != 'success'):
            raise ValueError('untrusted native producer')
        rows = document['artifacts']
        if (not isinstance(rows, list) or type(document['total_count']) is not int or
                document['total_count'] != len(rows) or len(rows) > 2000):
            raise ValueError('incomplete artifact collection')
        expected = f'native-release-{platform}-{sha}-{run_id}-{attempt}'
        selected = []
        ids, names = set(), set()
        for item in rows:
            owner, name, identifier = item['workflow_run'], item['name'], item['id']
            if (not isinstance(name, str) or not name or not _positive(identifier) or
                    name in names or identifier in ids or not _positive(owner['id']) or owner['id'] != run_id or
                    not _positive(owner['repository_id']) or not _positive(owner['head_repository_id']) or
                    owner['repository_id'] != repo['id'] or owner['head_repository_id'] != repo['id'] or
                    owner['head_sha'] != sha or owner['head_branch'] != branch):
                raise ValueError('foreign or duplicate artifact')
            names.add(name)
            ids.add(identifier)
            if name == expected:
                selected.append(item)
        if len(selected) != 1:
            raise ValueError('current native evidence artifact missing or ambiguous')
        item = selected[0]
        if (item['expired'] is not False or not _positive(item['size_in_bytes']) or
                item['size_in_bytes'] > 32_000_000 or not isinstance(item['digest'], str) or
                not re.fullmatch(r'sha256:[0-9a-f]{64}', item['digest'])):
            raise ValueError('native evidence artifact integrity unavailable')
    except (KeyError, TypeError, AttributeError) as error:
        raise ValueError('incomplete native producer metadata') from error
    return {'status': 'CANDIDATE_UNVERIFIED', 'published': 'UNKNOWN',
            'source_revision': sha, 'run_id': run_id, 'run_attempt': attempt,
            'platform': platform, 'tag': tag,
            'artifact_id': item['id'], 'artifact_digest': item['digest'],
            'artifact_size': item['size_in_bytes']}
