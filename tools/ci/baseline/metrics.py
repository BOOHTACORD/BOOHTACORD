"""Seconds are wall time; job-minutes are execution occupancy, never billing."""
from datetime import datetime
from math import ceil


def elapsed(start, end):
    if not start or not end:
        return None
    try:
        delta = (datetime.fromisoformat(end.replace('Z', '+00:00')) -
                 datetime.fromisoformat(start.replace('Z', '+00:00'))).total_seconds()
        return delta if delta >= 0 else None
    except (ValueError, TypeError):
        return None


def distribution(values):
    values = sorted(v for v in values if v is not None)
    return {'n': len(values), **{f'p{p}': values[ceil(len(values) * p / 100) - 1] if values else None
                               for p in (50, 90, 95)}, 'max': max(values) if values else None}


def run_metrics(run):
    jobs = [j for j in run['jobs'] if j.get('conclusion') != 'skipped']
    durations = [elapsed(j.get('started_at'), j.get('completed_at')) for j in jobs]
    complete = run.get('status') == 'completed' and bool(jobs) and all(x is not None for x in durations)
    end = max((j['completed_at'] for j in jobs), default=None) if complete else None
    ready = run.get('created_at')
    return {'wall_seconds': elapsed(ready, end),
            'job_minutes': attempt_minutes(run),
            'completion_drivers': [j['name'] for j in jobs if end and j.get('completed_at') == end],
            'first_job_delay_seconds': elapsed(ready, min((j['started_at'] for j in jobs
                                                         if j.get('started_at')), default=None)),
            'attempt_execution_span_seconds': elapsed(min((j['started_at'] for j in jobs
                                                          if j.get('started_at')), default=None), end)}


def summarize(runs):
    completed = [r for r in runs if r.get('status') == 'completed']
    metrics = [run_metrics(r) for r in completed]
    success = [m for r, m in zip(completed, metrics) if r.get('conclusion') == 'success']
    n = len(completed)
    return {'n': n, 'urls': [r['url'] for r in completed],
            'success_wall_seconds': distribution([m['wall_seconds'] for m in success]),
            'job_minutes': distribution([m['job_minutes'] for m in metrics]),
            'failure_rate': sum(r.get('conclusion') in ('failure', 'timed_out', 'action_required',
                                                      'startup_failure') for r in completed) / n if n else None,
            'cancelled_rate': sum(r.get('conclusion') == 'cancelled' for r in completed) / n if n else None,
            'retried_run_rate': sum((r.get('run_attempt') or 1) > 1 for r in completed) / n if n else None,
            'confirmed_flake_rate': None}


def attempt_minutes(run):
    attempts = run.get('attempts') or [{'jobs': run['jobs']}]
    values, seen = [], set()
    for attempt in attempts:
        jobs = [j for j in attempt['jobs'] if j.get('conclusion') != 'skipped']
        if not jobs:
            return None
        for job in jobs:
            identity = job.get('id')
            if identity is not None and identity in seen:
                continue
            seen.add(identity)
            values.append(elapsed(job.get('started_at'), job.get('completed_at')))
    if run.get('status') != 'completed' or any(v is None for v in values):
        return None
    return round(sum(values) / 60, 4)
