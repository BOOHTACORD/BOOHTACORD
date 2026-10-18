import unittest
from .metrics import distribution, elapsed, run_metrics, summarize


def job(name, start, end, conclusion='success'):
    return {'id': name, 'name': name, 'started_at': start, 'completed_at': end,
            'status': 'completed', 'conclusion': conclusion, 'steps': []}


T0, T1, T2 = ('2026-10-18T00:00:00Z', '2026-10-18T00:01:00Z', '2026-10-18T00:02:00Z')


class MetricsTests(unittest.TestCase):
    def test_percentiles_use_nearest_rank_and_keep_zero(self):
        self.assertEqual(distribution([None, 0, 60, 120, 180]),
                         {'n': 4, 'p50': 60, 'p90': 180, 'p95': 180, 'max': 180})
        self.assertEqual(distribution([])['p95'], None)

    def test_missing_reversed_and_in_progress_are_not_zero(self):
        self.assertIsNone(elapsed(None, T1))
        self.assertIsNone(elapsed(T1, T0))
        run = {'created_at': T0, 'status': 'in_progress', 'jobs': [job('a', T0, None)]}
        result = run_metrics(run)
        self.assertIsNone(result['wall_seconds'])
        self.assertIsNone(result['job_minutes'])

    def test_parallel_minutes_are_not_wall_clock(self):
        run = {'created_at': T0, 'status': 'completed', 'jobs': [job('a', T0, T2), job('b', T0, T2)]}
        result = run_metrics(run)
        self.assertEqual(result['wall_seconds'], 120)
        self.assertEqual(result['job_minutes'], 4)
        self.assertEqual(result['completion_drivers'], ['a', 'b'])

    def test_skipped_jobs_do_not_poison_durations(self):
        run = {'created_at': T0, 'status': 'completed',
               'jobs': [job('a', T0, T1), job('skip', None, None, 'skipped')]}
        self.assertEqual(run_metrics(run)['job_minutes'], 1)

    def test_cancelled_partial_work_is_cost_but_not_success_latency(self):
        run = {'created_at': T0, 'status': 'completed', 'conclusion': 'cancelled',
               'url': 'u', 'run_attempt': 1, 'jobs': [job('a', T0, T1, 'cancelled')]}
        summary = summarize([run])
        self.assertEqual(summary['success_wall_seconds']['n'], 0)
        self.assertEqual(summary['job_minutes']['p50'], 1)
        self.assertEqual(summary['cancelled_rate'], 1)

    def test_missing_one_active_job_makes_cost_unknown(self):
        run = {'created_at': T0, 'status': 'completed',
               'jobs': [job('a', T0, T1), job('b', None, None)]}
        self.assertIsNone(run_metrics(run)['job_minutes'])
        self.assertIsNone(run_metrics(run)['wall_seconds'])

    def test_failure_and_retry_rates_are_not_flake_rates(self):
        rows = [{'created_at': T0, 'status': 'completed', 'conclusion': c, 'run_attempt': a,
                 'url': str(a) + c, 'jobs': [job('a', T0, T1, c)]}
                for c, a in [('failure', 1), ('success', 2), ('cancelled', 1)]]
        summary = summarize(rows)
        self.assertAlmostEqual(summary['failure_rate'], 1 / 3)
        self.assertAlmostEqual(summary['retried_run_rate'], 1 / 3)
        self.assertIsNone(summary['confirmed_flake_rate'])
