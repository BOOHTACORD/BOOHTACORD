"""Allowed exact-source quality producers; a no-release route is not build evidence."""
from tools.release.delivery.provenance import validate

CI = '.github/workflows/ci.yaml'
SERVER = '.github/workflows/build-server.yaml'


def gate_names(run, jobs, repository):
    if run.get('head_repository', {}).get('full_name') != repository:
        raise ValueError('Foreign or missing quality producer head repository')
    gates = {'backend': 'backend / backend', 'web': 'frontend / frontend',
             'contracts': 'contracts / contracts'}
    path = run.get('path')
    if (path == CI and run.get('event') in ('push', 'workflow_dispatch')
            and run.get('head_branch') == 'master'):
        return gates
    if path == SERVER:
        validate(run, repository)
        bundles = [job for job in jobs if job.get('name') == 'bundle']
        if (len(bundles) != 1 or bundles[0].get('status') != 'completed'
                or bundles[0].get('conclusion') != 'success'):
            raise ValueError('A successful exact-source signed-bundle producer is required')
        gates['web'] = 'web / frontend'
        return gates
    raise ValueError('Unexpected quality producer workflow or event')
