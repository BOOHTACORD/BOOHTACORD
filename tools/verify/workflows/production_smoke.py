"""Constrain the post-install smoke jobs and their narrowly scoped credentials."""
from .selection import require

GUARD = "github.repository == 'BOOHTACORD/BOOHTACORD' && github.ref == 'refs/heads/master' && needs.install.result == 'success'"
LOCK = {'group': 'v-bootybay-production', 'cancel-in-progress': 'false'}


def check(workflows):
    for name, revision in (
        ('deploy-production.yaml', '${{ github.event.workflow_run.head_sha }}'),
        ('install-retained-release.yaml', '${{ inputs.revision }}'),
    ):
        job = workflows[name]['jobs'].get('smoke', {})
        expected = {'needs', 'if', 'environment', 'runs-on', 'timeout-minutes', 'permissions', 'steps'}
        if name == 'deploy-production.yaml': expected.add('concurrency')
        require(set(job) == expected and job.get('needs') == 'install' and job.get('if') == GUARD,
                'A successful install must be followed by the production smoke job')
        require(job.get('environment') == 'production-smoke' and job.get('runs-on') == 'ubuntu-24.04'
                and job.get('timeout-minutes') == '15' and job.get('permissions') == {'contents': 'read'},
                'Production smoke must use a bounded isolated environment')
        require(name != 'deploy-production.yaml' or job.get('concurrency') == LOCK,
                'Smoke must share the production writer lock')
        require(job.get('steps') == [
            {'uses': 'actions/checkout@v7', 'with': {'persist-credentials': 'false'}},
            {'uses': 'actions/setup-python@v7', 'with': {
                'python-version': "${{ runner.os == 'Linux' && '3.12.15' || '3.12.10' }}"}},
            {'name': 'Verify selected Python interpreter', 'run': 'python -m tools.ci.toolchains.runtime python'},
            {'name': 'Prepare locked dependency cache inputs', 'run': 'python3 -m tools.ci.toolchains.cache_inputs npm'},
            {'uses': 'actions/setup-node@v7', 'with': {'node-version-file': '.node-version', 'cache': 'npm',
                                                        'cache-dependency-path': '.out/ci/cache-inputs/npm.json'}},
            {'name': 'Install locked browser test dependencies', 'working-directory': 'clients/web',
             'run': 'npm ci --ignore-scripts'},
            {'name': 'Verify installed source and basic browser voice journey',
             'env': {'EXPECTED_REVISION': revision, 'SMOKE_LOGIN': '${{ secrets.PRODUCTION_SMOKE_LOGIN }}',
                     'SMOKE_PASSWORD': '${{ secrets.PRODUCTION_SMOKE_PASSWORD }}'},
             'run': 'node tools/qa/production_smoke/run.mjs'},
        ], 'Production smoke commands and credentials must be exact')
