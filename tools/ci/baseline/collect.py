"""Explicit cohorts prevent mixing PR, master, manual and native release timings."""
from urllib.parse import quote
from .changes import components
from .normalize import normalize_artifact, normalize_job, normalize_run

COHORTS = {
    'ci_pr': ('ci.yaml', 'pull_request', None),
    'ci_master': ('ci.yaml', 'push', 'master'),
    'server_build': ('build-server.yaml', 'push', 'master'),
    'deploy': ('deploy-production.yaml', 'workflow_run', 'master'),
    'android_release': ('android-release.yaml', None, None),
    'windows_release': ('windows-release.yaml', None, None),
    'macos_release': ('macos-release.yaml', None, None),
}


def sample(api, cohort, count):
    workflow, event, branch = COHORTS[cohort]
    path = f'/actions/workflows/{workflow}/runs?status=completed&per_page={count}'
    if event:
        path += '&event=' + quote(event)
    if branch:
        path += '&branch=' + quote(branch)
    # Deliberately take the latest bounded sample, not the entire workflow history.
    if hasattr(api, 'get'):
        return [r for r in api.get(path)['workflow_runs'] if r.get('status') == 'completed'][:count]
    return [r for r in api.pages(path, 'workflow_runs') if r.get('status') == 'completed'][:count]  # injected offline test reader


def collect_run(api, raw, repository, artifacts):
    run = normalize_run(raw)
    run['components'] = components(run.get('head_sha'), run.get('event'), repository)
    run['attempts'] = []
    for number in range(1, (run.get('run_attempt') or 1) + 1):
        jobs = api.pages(f'/actions/runs/{run["id"]}/attempts/{number}/jobs', 'jobs')
        run['attempts'].append({'number': number, 'jobs': [normalize_job(j) for j in jobs]})
    run['jobs'] = run['attempts'][-1]['jobs']
    run['artifacts'] = ([normalize_artifact(a) for a in api.pages(
        f'/actions/runs/{run["id"]}/artifacts', 'artifacts')] if artifacts else None)
    return run


def collect_cohort(api, cohort, count, repository, artifacts=False, progress=None):
    rows = []
    for raw in sample(api, cohort, count):
        if raw.get('status') != 'completed':
            continue
        run = collect_run(api, raw, repository, artifacts)
        rows.append(run)
        if progress:
            progress(run)
    return rows
