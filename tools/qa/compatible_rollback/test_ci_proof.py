import copy
import unittest
from .ci_proof import validate_run


def observations():
    run = {'id': 101, 'head_sha': 'a' * 40, 'status': 'completed', 'conclusion': 'success',
           'repository': {'full_name': 'Egkurilov/BOOHTACORD'}}
    jobs = {'total_count': 3, 'jobs': [
        {'id': i + 1, 'run_id': 101, 'name': name, 'status': 'completed', 'conclusion': 'success'}
        for i, name in enumerate(('backend / backend', 'frontend / frontend', 'contracts / contracts'))]}
    return run, jobs


class CIProofTests(unittest.TestCase):
    def test_success_is_bound_to_exact_repository_head_run_and_unique_gates(self):
        run, jobs = observations()
        proof = validate_run(run, jobs, 'a' * 40, 101)
        self.assertEqual(proof['head'], 'a' * 40)
        self.assertEqual(set(proof['checks']), {'backend', 'web', 'contracts'})
        self.assertEqual(proof['checks']['web']['id'], 2)

    def test_rejects_other_source_repository_or_incomplete_run(self):
        for mode in ('head', 'repository', 'pending', 'failure', 'run'):
            run, jobs = observations()
            if mode == 'head': run['head_sha'] = 'b' * 40
            if mode == 'repository': run['repository']['full_name'] = 'other/project'
            if mode == 'pending': run['status'] = 'in_progress'
            if mode == 'failure': run['conclusion'] = 'failure'
            if mode == 'run': run['id'] = 102
            with self.subTest(mode=mode), self.assertRaises(ValueError): validate_run(run, jobs, 'a' * 40, 101)

    def test_rejects_missing_duplicated_failed_or_foreign_jobs(self):
        for mode in ('missing', 'duplicate', 'failed', 'foreign', 'truncated'):
            run, jobs = observations()
            if mode == 'missing': jobs['jobs'].pop()
            if mode == 'duplicate': jobs['jobs'].append(copy.deepcopy(jobs['jobs'][0])); jobs['total_count'] += 1
            if mode == 'failed': jobs['jobs'][0]['conclusion'] = 'failure'
            if mode == 'foreign': jobs['jobs'][0]['run_id'] = 102
            if mode == 'truncated': jobs['total_count'] = 200
            with self.subTest(mode=mode), self.assertRaises(ValueError): validate_run(run, jobs, 'a' * 40, 101)
