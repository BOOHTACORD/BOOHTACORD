"""Choose a retained master producer and verify its immutable release authority."""
import json
import os
import re
from urllib.request import Request, urlopen
from tools.release.delivery.api import Reader
from tools.release.delivery.preflight import verified
from tools.release.delivery.consumer import REPOSITORY


def select(runs, reader_factory, verify=verified):
    if not isinstance(runs, list) or len(runs) > 100:
        raise ValueError('Invalid bounded producer list')
    for run in runs:
        if not isinstance(run, dict): raise ValueError('Invalid producer')
        number, source, attempt = run.get('id'), run.get('head_sha'), run.get('run_attempt')
        if (type(number) is not int or number <= 0 or type(attempt) is not int or attempt <= 0
                or not isinstance(source, str) or not re.fullmatch('[a-f0-9]{40}', source)):
            raise ValueError('Invalid producer identity')
        reader = reader_factory(str(number))
        rows = reader.collection('artifacts')['artifacts']
        names = {f'server-{source}', f'server-{source}-{number}-{attempt}'}
        if any(row.get('name') in names and row.get('expired') is not True for row in rows):
            return verify(reader, REPOSITORY, str(number), source)
    raise ValueError('No retained trusted producer in bounded search')


def main():
    if os.environ.get('GITHUB_REPOSITORY') != REPOSITORY: raise ValueError('Foreign repository')
    token = os.environ['GITHUB_TOKEN']
    url = ('https://api.github.com/repos/' + REPOSITORY +
           '/actions/workflows/build-server.yaml/runs?branch=master&status=success&per_page=100')
    request = Request(url, headers={'Authorization': 'Bearer ' + token, 'Accept': 'application/vnd.github+json'})
    try:
        with urlopen(request, timeout=30) as response: raw = response.read(2 * 1024 * 1024 + 1)
        if len(raw) > 2 * 1024 * 1024: raise ValueError('Oversized run list')
        runs = json.loads(raw)['workflow_runs']
        result = select(runs, lambda number: Reader(REPOSITORY, number, token))
    except Exception:
        raise SystemExit('Cannot discover a retained trusted producer') from None
    with open(os.environ['GITHUB_OUTPUT'], 'a', encoding='utf-8') as output:
        output.write(f'run_id={result["run_id"]}\nrevision={result["source_revision"]}\n')
    print('Retained trusted producer selected')


if __name__ == '__main__': main()
