"""Select an immutable bundle from the exact trusted producer execution."""
import re
from .provenance import validate


def positive(value):
    return type(value) is int and value > 0


def select(expected_run_id, run, document, repository, modern):
    source = validate(run, repository)
    if (not positive(expected_run_id) or not positive(run.get('id'))
            or run['id'] != expected_run_id or not positive(run.get('run_attempt'))
            or type(modern) is not bool):
        raise ValueError('Invalid producer execution identity')
    repo = run.get('repository', {})
    head = run.get('head_repository', {})
    if (repo.get('full_name') != repository or not positive(repo.get('id'))
            or not positive(head.get('id')) or head['id'] != repo['id']):
        raise ValueError('Foreign producer repository')
    rows = document.get('artifacts')
    if (not isinstance(rows, list) or type(document.get('total_count')) is not int
            or document['total_count'] != len(rows) or len(rows) > 2000):
        raise ValueError('Incomplete producer artifacts')
    ids, names, bundles = set(), set(), []
    attempt = run['run_attempt']
    name = f'server-{source}' + (f'-{expected_run_id}-{attempt}' if modern else '')
    for row in rows:
        if not isinstance(row, dict):
            raise ValueError('Invalid producer artifact')
        artifact_id, artifact_name = row.get('id'), row.get('name')
        if (not positive(artifact_id) or artifact_id in ids
                or not isinstance(artifact_name, str) or not artifact_name or artifact_name in names):
            raise ValueError('Duplicate or invalid artifact identity')
        ids.add(artifact_id)
        names.add(artifact_name)
        owner = row.get('workflow_run', {})
        if (type(owner.get('id')) is not int or owner['id'] != expected_run_id
                or type(owner.get('repository_id')) is not int or owner['repository_id'] != repo['id']
                or type(owner.get('head_repository_id')) is not int or owner['head_repository_id'] != repo['id']
                or owner.get('head_sha') != source or owner.get('head_branch') != 'master'):
            raise ValueError('Artifact does not belong to this producer')
        if artifact_name.startswith('server-'):
            if modern:
                match = re.fullmatch(re.escape(f'server-{source}-{expected_run_id}-') + r'([1-9][0-9]*)', artifact_name)
                if not match or int(match[1]) > attempt:
                    raise ValueError('Bundle execution differs from producer')
            elif artifact_name != name:
                raise ValueError('Unexpected legacy bundle identity')
            if artifact_name == name:
                bundles.append(row)
    if len(bundles) != 1:
        raise ValueError('Current producer bundle is missing or ambiguous')
    bundle = bundles[0]
    digest = bundle.get('digest')
    if (bundle.get('expired') is not False or not positive(bundle.get('size_in_bytes'))
            or (digest is None and modern)
            or (digest is not None and (not isinstance(digest, str)
                                       or not re.fullmatch(r'sha256:[0-9a-f]{64}', digest)))):
        raise ValueError('Bundle retention metadata is invalid')
    return {'id': bundle['id'], 'name': name, 'size_in_bytes': bundle['size_in_bytes'],
            'digest': digest, 'source_revision': source, 'run_id': expected_run_id,
            'run_attempt': attempt, 'format_version': 2 if modern else 1}
