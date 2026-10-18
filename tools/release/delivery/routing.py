"""Read-only producer preflight: a proven non-release route must not request deployment."""
import json
import os
import re
from urllib.request import Request, urlopen
from .provenance import validate

GATES = ('backend / backend', 'web / frontend', 'contracts / contracts')


def decision(run, document, repository):
    revision = validate(run, repository)
    jobs = document.get('jobs', [])
    if document.get('total_count') != len(jobs) or len({j.get('id') for j in jobs}) != len(jobs):
        raise ValueError('Incomplete or duplicate producer jobs')
    if any(j.get('run_id') != run['id'] or j.get('status') != 'completed'
           or j.get('conclusion') not in ('success', 'skipped') for j in jobs):
        raise ValueError('Producer jobs are not successful/expected skips')

    def one(name):
        matches = [j for j in jobs if j.get('name') == name]
        if len(matches) != 1:
            raise ValueError('Producer job identity is missing or ambiguous')
        return matches[0]['conclusion']

    bundle = one('bundle')
    expected = 'success' if bundle == 'success' else 'skipped'
    for name in GATES:
        caller = name.split(' / ')[0]
        matches = [job for job in jobs if job.get('name') in (name, caller)]
        required_name = name if bundle == 'success' else caller
        if (len(matches) != 1 or matches[0]['name'] != required_name
                or matches[0]['conclusion'] != expected):
            raise ValueError('Producer gates differ from bundle route')
    if bundle == 'skipped' and one('changes') != 'success':
        raise ValueError('No successful explicit non-release route')
    selectors = [j for j in jobs if j.get('name') == 'changes']
    if selectors and (len(selectors) != 1 or selectors[0]['conclusion'] != 'success'):
        raise ValueError('Change selection did not succeed')
    return {'revision': revision, 'run_id': run['id'], 'has_bundle': bundle == 'success'}


def main():
    repository, run_id = os.environ['GITHUB_REPOSITORY'], os.environ['BUILD_RUN_ID']
    if not re.fullmatch('[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+', repository) or not re.fullmatch('[0-9]+', run_id):
        raise ValueError('Invalid producer identity')
    root = f'https://api.github.com/repos/{repository}/actions/runs/{run_id}'

    def read(url):
        request = Request(url, headers={'Authorization': 'Bearer ' + os.environ['GITHUB_TOKEN'],
                                       'Accept': 'application/vnd.github+json'})
        with urlopen(request, timeout=30) as response:
            return json.load(response)

    run, jobs = read(root), []
    for page in range(1, 21):
        document = read(root + f'/jobs?filter=latest&per_page=100&page={page}')
        jobs.extend(document['jobs'])
        if len(jobs) == document['total_count']:
            break
        if not document['jobs']:
            raise ValueError('Truncated producer jobs')
    result = decision(run, {'jobs': jobs, 'total_count': document['total_count']}, repository)
    with open(os.environ['GITHUB_OUTPUT'], 'a', encoding='utf-8') as stream:
        stream.write(''.join(f'{key}={str(value).lower() if type(value) is bool else value}\n'
                             for key, value in result.items()))
    print('Verified trusted producer route: ' + ('release' if result['has_bundle'] else 'no release impact'))


if __name__ == '__main__':
    main()
