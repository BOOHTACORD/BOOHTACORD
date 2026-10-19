"""Only complete same-source hosted controls may establish the measured split."""
import copy
import unittest
from . import comparison, results, legacy
from .test_results import record


def fixtures():
    sha = 'a' * 40
    run = {'id': 123, 'run_attempt': 1, 'head_sha': sha,
           'repository': {'full_name': 'Egkurilov/BOOHTACORD'},
           'head_repository': {'full_name': 'Egkurilov/BOOHTACORD'},
           'path': '.github/workflows/flutter-ci-shadow.yaml', 'event': 'workflow_dispatch'}
    jobs = []
    def job(name, minutes, runner):
        jobs.append({'id': 100 + len(jobs), 'name': name, 'run_id': 123, 'run_attempt': 1, 'head_sha': sha,
                     'status': 'completed', 'conclusion': 'success', 'runner_id': runner,
                     'labels': ['ubuntu-24.04'], 'runner_group_name': 'GitHub Actions',
                     'created_at': '2026-10-19T00:00:00Z', 'started_at': '2026-10-19T00:00:01Z',
                     'completed_at': f'2026-10-19T00:{minutes:02d}:01Z'})
    old, new = [], []
    for sample in (1, 2, 3):
        job('legacy-' + str(sample), 20, 10 + sample)
        legacy_part = {'schema_version': 1, 'source_revision': sha, 'status': 'PASS',
                       'execution': {'run_id': '123', 'run_attempt': '1', 'namespace': 'shadow-old-' + str(sample)},
                       'sdk': results.expected_sdk(), 'baseline': legacy.reference(),
                       'operations': legacy.reference()['operations'], 'seconds': 1100,
                       'artifacts': {p: record(p)['artifacts'] for p in ('dart', 'android')}}
        old.append(legacy_part)
        parts = []
        for profile in ('dart', 'android', 'flutter'):
            job(f'profiles-{sample} / {profile}', 12 if profile == 'android' else 10, 100 + sample * 10 + len(parts))
            if profile == 'flutter':
                jobs[-1]['started_at'] = '2026-10-19T00:12:03Z'
                jobs[-1]['completed_at'] = '2026-10-19T00:12:13Z'
            if profile != 'flutter':
                part = record(profile); part['namespace'] = 'shadow-new-' + str(sample); parts.append(part)
        new.append(parts)
    job('compare', 1, 999)
    return run, {'jobs': jobs, 'total_count': len(jobs)}, {'legacy': {'result': 'success'}, 'profiles': {'result': 'success'}}, old, new


class ComparisonTests(unittest.TestCase):
    def test_whole_job_time_and_parallel_runner_cost_remain_distinct(self):
        value = comparison.compare(*fixtures())
        self.assertEqual('PASS', value['status'])
        self.assertEqual({'p50': 1200.0, 'p95': 1200.0}, value['summary']['legacy']['critical_seconds'])
        self.assertEqual({'p50': 732.0, 'p95': 732.0}, value['summary']['profiles']['critical_seconds'])
        self.assertEqual({'p50': 22.166667, 'p95': 22.166667}, value['summary']['profiles']['runner_minutes'])
        self.assertEqual(3, value['summary']['dart']['n'])
        self.assertEqual(3, value['summary']['android']['n'])

    def test_missing_failed_foreign_or_cancelled_jobs_are_rejected(self):
        for mutation in ('missing', 'duplicate', 'failed', 'source', 'attempt', 'runner', 'fanin'):
            args = fixtures(); jobs = args[1]['jobs']
            if mutation == 'missing': jobs.pop()
            elif mutation == 'duplicate': jobs[1]['name'] = jobs[0]['name']
            elif mutation == 'failed': jobs[1]['conclusion'] = 'cancelled'
            elif mutation == 'source': jobs[1]['head_sha'] = 'b' * 40
            elif mutation == 'attempt': jobs[1]['run_attempt'] = 2
            elif mutation == 'runner': jobs[2]['runner_id'] = jobs[1]['runner_id']
            else: jobs[3]['started_at'] = '2026-10-19T00:00:01Z'
            with self.subTest(mutation=mutation), self.assertRaises(ValueError): comparison.compare(*args)

    def test_partial_stale_unmeasured_or_foreign_parts_are_rejected(self):
        for mutation in ('partial', 'source', 'namespace', 'baseline', 'sdk', 'apk'):
            args = fixtures(); part = args[4][0][0]
            if mutation == 'partial': args[4].pop()
            elif mutation == 'source': part['source_revision'] = 'b' * 40
            elif mutation == 'namespace': part['namespace'] = 'shadow-new-2'
            elif mutation == 'baseline': args[3][0]['baseline']['source_revision'] = 'b' * 40
            elif mutation == 'sdk': part['sdk'] = {}
            else: args[4][0][1]['artifacts'].pop('app-debug.apk')
            with self.subTest(mutation=mutation), self.assertRaises(ValueError): comparison.compare(*args)

    def test_complete_slower_split_retains_no_gain_instead_of_passing(self):
        args = fixtures()
        for job in args[1]['jobs']:
            if job['name'].startswith('profiles-'):
                job['completed_at'] = '2026-10-19T00:25:01Z'
                if job['name'].endswith(' / flutter'):
                    job['started_at'] = '2026-10-19T00:25:03Z'
                    job['completed_at'] = '2026-10-19T00:25:13Z'
        self.assertEqual('NO_GAIN', comparison.compare(*args)['status'])
