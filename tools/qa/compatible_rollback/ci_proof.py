"""Read actual GitHub gate results; never infer a PASS from a caller's claim."""
import argparse
import json
import os
from pathlib import Path
import re
import subprocess
from urllib.error import HTTPError
from urllib.request import Request, urlopen

REPOSITORY = 'Egkurilov/BOOHTACORD'
GATES = {'backend': 'backend / backend', 'web': 'frontend / frontend', 'contracts': 'contracts / contracts'}


def require(value):
    if not value:
        raise ValueError('Exact successful source-bound GitHub CI gates are required')


def validate_run(run, jobs, head, run_id):
    require(run['id'] == run_id and run['head_sha'] == head
            and run['repository']['full_name'] == REPOSITORY
            and run['status'] == 'completed' and run['conclusion'] == 'success')
    require(jobs['total_count'] == len(jobs['jobs']) and jobs['total_count'] <= 100)
    selected = {}
    for gate, name in GATES.items():
        matches = [job for job in jobs['jobs'] if job['name'] == name]
        require(len(matches) == 1)
        job = matches[0]
        require(job['run_id'] == run_id and job['status'] == 'completed' and job['conclusion'] == 'success')
        selected[gate] = {'id': job['id'], 'conclusion': 'success'}
    return {'head': head, 'run': run_id, 'status': 'success', 'checks': selected}


def read(path):
    headers = {'Accept': 'application/vnd.github+json', 'X-GitHub-Api-Version': '2022-11-28', 'User-Agent': 'boohtacord-qa60'}
    token = os.environ.get('GITHUB_TOKEN')
    if token:
        headers['Authorization'] = 'Bearer ' + token
    try:
        with urlopen(Request('https://api.github.com/repos/' + REPOSITORY + path, headers=headers), timeout=30) as response:
            return json.load(response)
    except HTTPError as error:
        raise RuntimeError('GitHub CI metadata HTTP ' + str(error.code)) from None


def git(*args):
    return subprocess.check_output(['git', *args], text=True).strip()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('input', type=Path)
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    inputs = json.loads(args.input.read_text())
    result = {}
    for role in ('current', 'previous'):
        source = inputs[role]
        head, run_id = source['head'], source['run']
        require(re.fullmatch('[0-9a-f]{40}', head) and type(run_id) is int and run_id > 0)
        run = read('/actions/runs/' + str(run_id))
        jobs = read('/actions/runs/' + str(run_id) + '/jobs?filter=latest&per_page=100')
        proof = validate_run(run, jobs, head, run_id)
        proof['tree'] = git('rev-parse', head + '^{tree}')
        proof['equivalent_master'] = source['equivalent_master']
        require(proof['tree'] == git('rev-parse', source['equivalent_master'] + '^{tree}'))
        result[role] = proof
    # The images may be a retained CI head with the same master tree. They must
    # still contain the actual product/release code under review, without aliases.
    paths = ['backend', 'clients/web', 'contracts', 'deploy', 'tools/release', 'tools/build/server',
             'tools/audio', 'tools/toolchains.json', '.node-version', 'Taskfile.yml',
             'clients/flutter/packages/flutter_webrtc/common/rnnoise/upstream']
    require(subprocess.run(['git', 'diff', '--quiet', result['current']['head'], 'HEAD', '--', *paths]).returncode == 0)
    require(subprocess.run(['git', 'diff', '--quiet', result['current']['head'], result['previous']['head'],
                            '--', 'backend', 'contracts', 'deploy']).returncode == 0)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2) + '\n')
    print('PASS: observed successful CI gates for two exact compatible source heads')


if __name__ == '__main__':
    main()
