"""Partial or foreign shard evidence must never produce a Web release receipt."""
import copy
import unittest
from . import catalog, fan_in

SOURCE = 'a' * 40


def fixture():
    plan = catalog.plan()
    needs = {name: {'result': 'success'} for name in ('fast', 'browser', 'sfu')}
    rows = [{'source_revision': SOURCE, 'profile': profile,
             'plan_sha256': catalog.digest(plan), 'status': 'PASS',
             'operations': operations[:], 'seconds': 1.0, 'execution': catalog.execution()}
            for profile, operations in plan['profiles'].items()]
    return needs, rows


class FanInTests(unittest.TestCase):
    def test_missing_second_shell_group_fails_even_when_matrix_is_green(self):
        needs, rows = fixture()
        rows = [row for row in rows if row['profile'] != 'browser-content']
        with self.assertRaises(ValueError):
            fan_in.validate_results(SOURCE, needs, rows)

    def test_all_exact_source_profiles_are_required_for_success(self):
        needs, rows = fixture()
        self.assertEqual(fan_in.validate_results(SOURCE, needs, rows)['status'], 'PASS')

    def test_failed_cancelled_timeout_skipped_or_absent_job_is_not_pass(self):
        for name in ('fast', 'browser', 'sfu'):
            for state in ('failure', 'cancelled', 'skipped', 'timed_out', None):
                needs, rows = fixture(); needs[name]['result'] = state
                with self.subTest(name=name, state=state), self.assertRaises(ValueError):
                    fan_in.validate_results(SOURCE, needs, rows)
            needs, rows = fixture(); del needs[name]
            with self.assertRaises(ValueError): fan_in.validate_results(SOURCE, needs, rows)

    def test_missing_duplicate_foreign_and_incomplete_shard_cannot_be_replaced_by_green_job(self):
        for change in ('missing', 'duplicate', 'foreign', 'stale-plan', 'partial', 'failed',
                       'extra', 'invalid-time', 'empty-operations'):
            needs, rows = fixture()
            if change == 'missing': rows.pop()
            if change == 'duplicate': rows.append(copy.deepcopy(rows[0]))
            if change == 'foreign': rows[0]['source_revision'] = 'b' * 40
            if change == 'stale-plan': rows[0]['plan_sha256'] = 'b' * 64
            if change == 'partial': rows[0]['operations'].pop()
            if change == 'failed': rows[0]['status'] = 'FAIL'
            if change == 'extra': rows.append({**rows[0], 'profile': 'unreviewed'})
            if change == 'invalid-time': rows[0]['seconds'] = float('nan')
            if change == 'empty-operations': rows[0]['operations'] = []
            with self.subTest(change=change), self.assertRaises(ValueError):
                fan_in.validate_results(SOURCE, needs, rows)

    def test_same_source_from_another_run_attempt_or_namespace_is_not_current_evidence(self):
        for key in ('run_id', 'run_attempt', 'namespace'):
            needs, rows = fixture(); rows[0]['execution'][key] = 'other'
            with self.subTest(key=key), self.assertRaises(ValueError):
                fan_in.validate_results(SOURCE, needs, rows)
