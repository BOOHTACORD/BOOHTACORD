"""Bounded categories guide diagnosis; they never suppress or retry a quality gate."""
import hashlib
import re

REPRO={
    'backend':('Backend/CI','python -m tools.ci.native.backend'),
    'web':('Web/CI','python -m tools.ci.native.web'),
    'flutter':('Native/CI','python -m tools.ci.native.flutter'),
    'windows':('Windows/Media','python -m tools.ci.windows_gates.acceptance'),
    'contracts':('CI/Contracts','python -m tools.ci.native.contracts'),
    'actual':('QA/Media','python -m tools.ci.actual_acceptance.run --profile lifecycle --baseline <exact-base-sha>'),
    'delivery':('Release/Operations','python -m unittest tools.release.delivery.test_workflows'),
    'unknown':('CI/Triage','Inspect the source-bound job link; exact local command is not verified'),
}


def require(value):
    if not value:raise ValueError('CI triage metadata is incomplete, stale or invalid')


def component(name):
    name=(name or '').lower()
    for prefixes,role in [(('windows','screen-setup','desktop-recovery'),'windows'),(('backend',),'backend'),
        (('frontend','web','browser'),'web'),(('flutter','dart','android'),'flutter'),(('contracts',),'contracts'),
        (('actual','lifecycle','sfu','next'),'actual'),(('install','bundle','deploy'),'delivery')]:
        if name.startswith(prefixes):return role
    return 'unknown'


def stage(name):
    name=(name or '').lower()
    if any(value in name for value in ('upload-artifact','retain ','retention','download-artifact')):return 'evidence'
    if any(value in name for value in ('signed','signing','publish')):return 'signing-or-publication'
    if any(value in name for value in ('real windows gui','actual','sfu','acceptance')):return 'runtime-acceptance'
    return 'component-check'


def classify(run,jobs):
    conclusion=run.get('conclusion');event=run.get('event')
    outcome=('CANCELLED' if conclusion=='cancelled' else 'PASS' if conclusion=='success' else
             'BLOCKED' if run.get('status') in ('queued','waiting','pending') or conclusion in ('action_required','startup_failure') else
             'NOT_RUN' if run.get('status')!='completed' and not conclusion else 'FAIL')
    failures=[]
    for job in jobs:
        steps=[s for s in job.get('steps',[]) if s.get('conclusion') in ('failure','timed_out')]
        if not steps and job.get('conclusion') not in ('failure','timed_out','action_required','startup_failure'):continue
        step=steps[0] if steps else {};role=component(job.get('name'));number=step.get('number')
        if type(number) is not int or not 0<number<=500:number=None
        name=step.get('name','');kind=stage(name)
        fingerprint=hashlib.sha256((str(run.get('path'))+'|'+role+'|'+name).encode()).hexdigest()
        failures.append(dict(component=role,owner=REPRO[role][0],reproduce=REPRO[role][1],stage=kind,
            job_id=job.get('id') if type(job.get('id')) is int else None,step_number=number,
            fingerprint=fingerprint,critical_step=kind+' / step '+str(number) if number else 'job startup / step unavailable',
            root_cause='UNVERIFIED',retry_test=False))
    return dict(outcome=outcome,failures=failures,retry_test=False,confirmed_flake='UNKNOWN',
                master_defect=False if event=='pull_request' and outcome=='CANCELLED' else None)


def binding(run,env,source,parents):
    require(re.fullmatch('[0-9a-f]{40}',source) and run.get('repository',{}).get('full_name')=='Egkurilov/BOOHTACORD'
            and str(run.get('id'))==env.get('GITHUB_RUN_ID') and str(run.get('run_attempt'))==env.get('GITHUB_RUN_ATTEMPT'))
    if run.get('head_sha')==source:return 'checked_checkout'
    require(run.get('event')==env.get('GITHUB_EVENT_NAME')=='pull_request'
            and re.fullmatch('refs/pull/[1-9][0-9]*/merge',env.get('GITHUB_REF',''))
            and len(parents)==2 and parents[1]==run.get('head_sha'))
    return 'checked_pr_merge_parent'
