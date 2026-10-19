"""Actionable waiting/evidence signals; metadata alone does not diagnose an offline runner."""
from datetime import datetime,timezone
from tools.ci.baseline.metrics import elapsed
from .policy import load


def detect(run,jobs,failures,now=None):
    policy=load();now=now or datetime.now(timezone.utc).isoformat();rows=[]
    age=elapsed(run.get('created_at'),now)
    if run.get('status') in ('queued','waiting','pending') and age is not None and age>=policy['stuck_required_warning_seconds']:
        rows.append(dict(kind='workflow-or-required-status-wait',cause='UNVERIFIED',owner='CI/Operations'))
    for job in jobs:
        delay=elapsed(job.get('created_at'),now)
        if job.get('status') in ('queued','waiting') and 'self-hosted' in (job.get('labels') or []) and delay is not None and delay>=policy['self_hosted_wait_warning_seconds']:
            rows.append(dict(kind='self-hosted-runner-or-approval-wait',cause='UNVERIFIED',owner='CI/Operations'))
    if any(f['stage']=='evidence' for f in failures):rows.append(dict(kind='required-evidence-failed',owner='CI/Artifacts'))
    return rows
