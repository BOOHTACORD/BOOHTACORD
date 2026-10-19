"""Read-only producer preflight: a proven non-release route must not request deployment."""
import json
import os
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
    modern = any(j.get('name') == 'server-quality' for j in jobs)
    if modern:
        if (one('server-quality') != 'success' or one('changes') != 'success'
                or type(run.get('run_attempt')) is not int or run['run_attempt'] <= 0
                or any(type(j.get('run_attempt')) is not int
                       or j['run_attempt'] != run['run_attempt'] for j in jobs)):
            raise ValueError('Master quality is not bound to this successful attempt')
    expected = 'success' if bundle == 'success' else 'skipped'
    for name in GATES:
        caller = name.split(' / ')[0]
        matches = [job for job in jobs if job.get('name') in (name, caller)]
        always_contracts = modern and name == 'contracts / contracts'
        required_name = name if bundle == 'success' or always_contracts else caller
        if (len(matches) != 1 or matches[0]['name'] != required_name
                or matches[0]['conclusion'] != ('success' if always_contracts else expected)):
            raise ValueError('Producer gates differ from bundle route')
    if bundle == 'skipped' and one('changes') != 'success':
        raise ValueError('No successful explicit non-release route')
    selectors = [j for j in jobs if j.get('name') == 'changes']
    if selectors and (len(selectors) != 1 or selectors[0]['conclusion'] != 'success'):
        raise ValueError('Change selection did not succeed')
    return {'revision': revision, 'run_id': run['id'], 'has_bundle': bundle == 'success',
            'format_version': 2 if modern else 1}


def main():
    from .api import Reader
    repository, run_id = os.environ['GITHUB_REPOSITORY'], os.environ['BUILD_RUN_ID']
    reader = Reader(repository, run_id, os.environ['GITHUB_TOKEN'])
    run = reader.read()
    if run.get('id') != int(run_id):
        raise ValueError('Producer run differs from request')
    result = decision(run, reader.collection('jobs'), repository)
    with open(os.environ['GITHUB_OUTPUT'], 'a', encoding='utf-8') as stream:
        stream.write(''.join(f'{key}={str(value).lower() if type(value) is bool else value}\n'
                             for key, value in result.items()))
    print('Verified trusted producer route: ' + ('release' if result['has_bundle'] else 'no release impact'))


if __name__ == '__main__':
    main()
