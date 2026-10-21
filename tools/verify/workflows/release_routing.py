"""Ensure release routing shares the PR selector and cannot authorize deployment."""
from tools.ci.runner_pool.routing import GITHUB_LINUX
from .selection import require
from tools.ci.toolchains.auxiliary import ROOT, python_input

SELECT = 'python3 -m tools.ci.select_changes.run'
IMPACT = "needs.changes.outputs.server_release_impact == 'true'"
TRUST = ("conclusion == 'success'", "head_branch == 'master'", 'head_repository.full_name == github.repository')


def check(build, deploy, gates):
    trigger = build['on']['push']
    require(trigger == {'branches': ['master']}, 'Server routing must not use a separate static path filter')
    selector = build['jobs']['changes']
    require(any(s.get('run') == SELECT for s in selector.get('steps', [])), 'Server build must use the common selector')
    require(selector.get('outputs', {}).get('server_release_impact') == '${{ steps.select.outputs.server_release_impact }}',
            'Server release impact must come from the common dependency map')
    for name in gates:
        job = build['jobs'][name]
        require(job.get('needs') == 'changes' and job.get('if') == (None if name == 'contracts' else IMPACT),
                'Contracts always run; heavy server gates must follow release impact')
    route = deploy['jobs']['route']
    require(not deploy.get('concurrency') and not route.get('concurrency'),
            'Read-only routing must stay outside concurrency queues before bundle qualification')
    require(not route.get('environment') and not route.get('env') and not route.get('secrets'),
            'Read-only route must not enter production or receive deployment credentials')
    require(route.get('permissions') == {'contents': 'read', 'actions': 'read'}, 'Route needs only metadata read permission')
    require(route.get('runs-on') == GITHUB_LINUX, 'Route must run on a GitHub-hosted Linux runner')
    steps = route.get('steps', [])
    require(len(steps) == 4 and steps[0] == {'uses': 'actions/checkout@v4', 'with': {'persist-credentials': 'false'}}, 'Route checkout/actions must remain bounded')
    require(steps[1] == {'uses': 'actions/setup-python@v5', 'with': {'python-version': python_input(ROOT)}}
            and steps[2] == {'name': 'Verify selected Python interpreter',
                             'run': 'python -m tools.ci.toolchains.runtime python'},
            'Route may only add the exact reviewed read-only Python bootstrap')
    reader = steps[3]
    require(reader.get('run') == 'python3 -m tools.release.delivery.routing' and reader.get('id') == 'route',
            'Route may only execute the read-only producer metadata verifier')
    require(reader.get('env') == {'BUILD_RUN_ID': '${{ github.event.workflow_run.id }}',
                                  'GITHUB_TOKEN': '${{ secrets.GITHUB_TOKEN }}'}, 'Route must not receive signing/SSH secrets')
    require(route.get('outputs') == {'has_bundle': '${{ steps.route.outputs.has_bundle }}'}, 'Only verified route can gate install')
    for guard in TRUST:
        require(guard in route.get('if', ''), 'Untrusted producer must not enter route verification')
    install = deploy['jobs']['install']
    require(install.get('needs') == 'route' and "needs.route.outputs.has_bundle == 'true'" in install.get('if', ''),
            'Production install must depend on the proven release route')
