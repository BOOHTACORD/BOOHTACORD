"""Check the stable aggregate and its edges without relying on component job IDs."""
import json


def check(document, roles, require):
    jobs = document['jobs']
    candidates = [job for job in jobs.values() if job.get('name') == 'ci-required']
    require(len(candidates) == 1, 'Exactly one stable ci-required job is required')
    job = candidates[0]
    require(job.get('if') == 'always()' and set(job.get('needs', [])) == set(roles.values()),
            'Required aggregate must always observe every selector/contract/component job')
    require(not job.get('continue-on-error'), 'Required aggregate failure cannot be ignored')
    require(job.get('runs-on') == 'ubuntu-24.04', 'Required aggregate must use an isolated hosted runner')
    checks = [s for s in job.get('steps', []) if s.get('run') == 'python3 -m tools.ci.required_gate.run']
    require(len(checks) == 1 and not checks[0].get('if') and not checks[0].get('continue-on-error'),
            'Required validator must execute without ignoring failure')
    env = checks[0].get('env', {})
    require(env.get('CI_NEEDS') == '${{ toJSON(needs) }}', 'Needs must be passed through environment JSON')
    try:
        declared = json.loads(env.get('CI_JOBS', ''))
    except (ValueError, TypeError):
        declared = None
    require(declared == roles, 'Aggregate role map must match the actual dependency graph')
    from tools.ci.observability.workflow import check_job
    check_job(job,'pr')
    for name in roles.values():
        require(not jobs[name].get('continue-on-error'), 'Mandatory selector/contracts/components cannot ignore failures')
    outputs = jobs[roles['changes']].get('outputs', {})
    for key in ('contracts', 'backend', 'web', 'flutter', 'windows', 'map_version', 'map_sha256', 'uncertain', 'actual_profiles', 'actual_required', 'actual_map_sha256', 'actual_release_required', 'actual_physical_required'):
        require(outputs.get(key) == '${{ steps.select.outputs.' + key + ' }}', 'Selector evidence must reach the aggregate')
