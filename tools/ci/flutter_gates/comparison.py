"""Measure complete same-source native shadow samples from actual job intervals."""
from datetime import datetime
import math
import re
from . import legacy, profiles, results


def require(value):
    if not value:
        raise ValueError('Incomplete or inconsistent source-bound native shadow measurement')


def positive(value):
    require(type(value) in (int, float) and math.isfinite(value) and value > 0)
    return value


def interval(job):
    require(job['status'] == 'completed' and job['conclusion'] == 'success')
    times = [datetime.fromisoformat(job[k].replace('Z', '+00:00'))
             for k in ('created_at', 'started_at', 'completed_at')]
    require(all(t.tzinfo is not None for t in times) and times[0] <= times[1] < times[2])
    return [t.timestamp() for t in times]


def percentiles(values):
    require(len(values) == 3)
    values = sorted(positive(v) for v in values)
    return {'p50': round(values[1], 6), 'p95': round(values[2], 6)}


def compare(run, jobs, needs, old, new):
    try:
        return _compare(run, jobs, needs, old, new)
    except (KeyError, TypeError, AttributeError, IndexError, OverflowError) as error:
        raise ValueError('Malformed native shadow measurement') from error


def _compare(run, jobs, needs, old, new):
    sha, run_id, attempt = run['head_sha'], run['id'], run['run_attempt']
    require(isinstance(sha, str) and re.fullmatch('[0-9a-f]{40}', sha)
            and type(run_id) is int and run_id > 0 and type(attempt) is int and attempt > 0)
    require(run['repository']['full_name'] == run['head_repository']['full_name'] == 'Egkurilov/BOOHTACORD'
            and run['path'] == '.github/workflows/flutter-ci-shadow.yaml'
            and run['event'] in ('workflow_dispatch', 'push'))
    require(set(needs) == {'legacy', 'profiles'} and all(v.get('result') == 'success' for v in needs.values()))
    names = {'compare'} | {'legacy-' + str(n) for n in (1, 2, 3)} | {
        f'profiles-{n} / {p}' for n in (1, 2, 3) for p in (*profiles.OPERATIONS, 'flutter')}
    require(jobs['total_count'] == len(jobs['jobs']) == len(names)
            and {j['name'] for j in jobs['jobs']} == names and len({j['id'] for j in jobs['jobs']}) == len(names))
    require(all(type(j['id']) is int and j['id'] > 0 and j['head_sha'] == sha
                and j['run_id'] == run_id and j['run_attempt'] == attempt
                and j['labels'] == ['ubuntu-24.04'] and j['runner_group_name'] == 'GitHub Actions'
                for j in jobs['jobs']))
    by_name = {j['name']: j for j in jobs['jobs']}
    require(len(old) == len(new) == 3)
    arms = {'legacy': [], 'profiles': [], 'dart': [], 'android': [], 'android-kotlin': []}

    def measured(sample, selected, driver):
        times = [interval(j) for j in selected]
        start, end = min(t[1] for t in times), max(t[2] for t in times)
        require(positive(driver) <= end - start + 1)
        return {'sample': sample, 'critical_seconds': round(end - start, 6),
                'runner_minutes': round(sum(t[2] - t[1] for t in times) / 60, 6),
                'created_to_first_start_seconds': round(start - min(t[0] for t in times), 6),
                'driver_critical_seconds': driver, 'job_ids': [j['id'] for j in selected]}

    for n in (1, 2, 3):
        matches = [r for r in old if r.get('execution', {}).get('namespace') == 'shadow-old-' + str(n)]
        require(len(matches) == 1)
        row = matches[0]
        require(set(row) == {'schema_version', 'source_revision', 'status', 'execution', 'sdk',
                             'baseline', 'operations', 'seconds', 'artifacts'}
                and type(row['schema_version']) is int and row['schema_version'] == 1
                and row['source_revision'] == sha and row['status'] == 'PASS'
                and row['execution'] == {'run_id': str(run_id), 'run_attempt': str(attempt), 'namespace': 'shadow-old-' + str(n)}
                and row['sdk'] == results.expected_sdk() and row['baseline'] == legacy.reference()
                and row['operations'] == legacy.reference()['operations'] and set(row['artifacts']) == {'dart', 'android'})
        for profile in ('dart', 'android'):
            results.validate_artifacts(profile, row['artifacts'][profile])
        arms['legacy'].append(measured(n, [by_name['legacy-' + str(n)]], row['seconds']))
        matches = [parts for parts in new if len(parts) == len(profiles.OPERATIONS) and
                   all(p.get('namespace') == 'shadow-new-' + str(n) for p in parts)]
        require(len(matches) == 1)
        parts = results.validate(matches[0], {p: {'result': by_name[f'profiles-{n} / {p}']['conclusion']}
                                             for p in profiles.OPERATIONS}, sha, str(run_id), str(attempt), 'shadow-new-' + str(n))
        selected = [by_name[f'profiles-{n} / {p}'] for p in (*profiles.OPERATIONS, 'flutter')]
        require(all(type(j.get('runner_id')) is int and j['runner_id'] > 0 for j in selected)
                and len({j['runner_id'] for j in selected[:-1]}) == len(profiles.OPERATIONS))
        require(interval(selected[-1])[1] >= max(interval(j)[2] for j in selected[:-1]))
        for profile, job in zip(profiles.OPERATIONS, selected[:-1]):
            arms[profile].append(measured(n, [job], parts[profile]['seconds']))
        arms['profiles'].append(measured(n, selected, max(p['seconds'] for p in parts.values())))
    summary = {name: {'n': 3, **{key: percentiles([r[key] for r in rows])
               for key in ('critical_seconds', 'runner_minutes')}} for name, rows in arms.items()}
    faster = all(summary['profiles']['critical_seconds'][p] < summary['legacy']['critical_seconds'][p] for p in ('p50', 'p95'))
    return {'schema_version': 1, 'source_revision': sha, 'run_id': run_id, 'run_attempt': attempt,
            'status': 'PASS' if faster else 'NO_GAIN', 'samples': arms, 'summary': summary,
            'baseline': legacy.reference(), 'original_coverage_preserved': True,
            'scope': 'Actual SDK/setup/test/upload/fan-in job intervals; n=3 nearest-rank descriptive p50/p95. Initial wait may include deliberate serial sampling. No billing, device/media acceptance, flake-rate or general CI SLO claim.'}
