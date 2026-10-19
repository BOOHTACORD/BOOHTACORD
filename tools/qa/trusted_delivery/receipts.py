"""Project independently observed QA provenance onto the shipping receipt contract."""
import json
from pathlib import Path
import re


def write(directory, revision, observed):
    try:
        gates = ('backend', 'web', 'contracts')
        if (not re.fullmatch('[a-f0-9]{40}', revision) or observed['head'] != revision
                or observed['status'] != 'success' or type(observed['run']) is not int or observed['run'] <= 0
                or observed['producer_workflow'] != '.github/workflows/build-server.yaml'
                or set(observed['checks']) != set(gates)):
            raise ValueError
        ids = []
        for gate in gates:
            row = observed['checks'][gate]
            if type(row['id']) is not int or row['id'] <= 0 or row['conclusion'] != 'success': raise ValueError
            ids.append(row['id'])
        if len(set(ids)) != 3: raise ValueError
    except (KeyError, TypeError, ValueError):
        raise ValueError('Observed exact successful master build gates are required') from None
    directory = Path(directory)
    directory.mkdir(mode=0o700, exist_ok=False)
    for gate in gates:
        (directory/(gate+'.json')).write_text(json.dumps({
            'source_revision': revision, 'gate': gate, 'status': 'PASS'})+'\n')
