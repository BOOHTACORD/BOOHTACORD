"""Accept artifacts only from this repository's successful protected server build."""
import os
import re


def validate(run, repository, revision=None):
    source = run.get('head_sha', '')
    if not re.fullmatch(r'[0-9a-f]{40}', source): raise ValueError('Invalid build source revision')
    if revision is not None and revision != source: raise ValueError('Requested revision differs from build')
    if run.get('head_repository', {}).get('full_name') != repository: raise ValueError('Foreign build repository')
    if run.get('path') != '.github/workflows/build-server.yaml': raise ValueError('Unexpected producer workflow')
    if run.get('head_branch') != 'master' or run.get('event') not in ('push', 'workflow_dispatch'):
        raise ValueError('Build did not originate from master')
    if run.get('conclusion') != 'success' or run.get('status') != 'completed': raise ValueError('Build is incomplete')
    return source


def main():
    from .api import Reader
    from .preflight import verified
    repository = os.environ['GITHUB_REPOSITORY']
    run_id = os.environ['BUILD_RUN_ID']
    reader = Reader(repository, run_id, os.environ['GITHUB_TOKEN'])
    artifact = verified(reader, repository, run_id, os.environ.get('REQUESTED_REVISION') or None)
    revision = artifact['source_revision']
    with open(os.environ['GITHUB_OUTPUT'], 'a', encoding='utf-8') as stream:
        stream.write(f'revision={revision}\nrun_id={run_id}\nrun_attempt={artifact["run_attempt"]}\n'
                     f'artifact_id={artifact["id"]}\nartifact_name={artifact["name"]}\n')
    print('Verified successful master build ' + run_id + ' at ' + revision)


if __name__ == '__main__': main()
