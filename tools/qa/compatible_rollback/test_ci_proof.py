import copy
import unittest
from .ci_proof import validate_run


def observations():
    run = {'id': 101, 'head_sha': 'a' * 40, 'status': 'completed', 'conclusion': 'success',
           'repository': {'full_name': 'Egkurilov/BOOHTACORD'},
           'head_repository': {'full_name': 'Egkurilov/BOOHTACORD'},
           'path': '.github/workflows/ci.yaml', 'event': 'push', 'head_branch': 'master'}
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

    def test_other_workflows_fork_heads_and_untrusted_events_are_not_quality_producers(self):
        for change in [{'path': '.github/workflows/ci-required-proof.yaml'},
                       {'head_repository': {'full_name': 'foreign/repo'}},
                       {'event': 'pull_request_target'}, {'head_repository': {}}]:
            run, jobs = observations();run.update(change)
            with self.subTest(change=change), self.assertRaises(ValueError):
                validate_run(run, jobs, 'a' * 40, 101)

    def test_master_signed_bundle_producer_has_the_same_three_exact_source_gates(self):
        run, jobs = observations()
        run.update(path='.github/workflows/build-server.yaml', event='push', head_branch='master')
        jobs['jobs'][1]['name'] = 'web / frontend'
        jobs['jobs'].append({'id': 4, 'run_id': 101, 'name': 'bundle',
                             'status': 'completed', 'conclusion': 'success'})
        jobs['total_count'] = 4
        proof = validate_run(run, jobs, 'a' * 40, 101)
        self.assertEqual(proof['checks']['web']['id'], 2)
        self.assertEqual(proof['producer_workflow'], '.github/workflows/build-server.yaml')
        for mode in ('no_bundle', 'skip_bundle', 'failed_bundle', 'foreign_bundle',
                     'duplicate_bundle', 'feature_branch', 'pr_event', 'wrapper_skips'):
            changed_run, changed_jobs = copy.deepcopy(run), copy.deepcopy(jobs)
            if mode == 'no_bundle': changed_jobs['jobs'].pop();changed_jobs['total_count'] -= 1
            if mode == 'skip_bundle': changed_jobs['jobs'][-1]['conclusion'] = 'skipped'
            if mode == 'failed_bundle': changed_jobs['jobs'][-1]['conclusion'] = 'failure'
            if mode == 'foreign_bundle': changed_jobs['jobs'][-1]['run_id'] = 102
            if mode == 'duplicate_bundle':
                changed_jobs['jobs'].append(dict(changed_jobs['jobs'][-1], id=99));changed_jobs['total_count'] += 1
            if mode == 'feature_branch': changed_run['head_branch'] = 'codex/fixture'
            if mode == 'pr_event': changed_run['event'] = 'pull_request'
            if mode == 'wrapper_skips':
                for job in changed_jobs['jobs'][:3]:
                    job.update(name=job['name'].split(' / ')[0], conclusion='skipped')
            with self.subTest(mode=mode), self.assertRaises(ValueError):
                validate_run(changed_run, changed_jobs, 'a' * 40, 101)

    def test_duplicate_job_ids_cannot_hide_behind_an_unrelated_name(self):
        run, jobs = observations()
        jobs['jobs'].append(dict(jobs['jobs'][0], name='unrelated'))
        jobs['total_count'] += 1
        with self.assertRaises(ValueError): validate_run(run, jobs, 'a' * 40, 101)

    def test_pr_merge_queue_and_feature_dispatch_are_not_master_quality_receipts(self):
        for change in [{'event': 'pull_request'}, {'event': 'merge_group'},
                       {'event': 'workflow_dispatch', 'head_branch': 'codex/fixture'}]:
            run, jobs = observations();run.update(change)
            with self.subTest(change=change), self.assertRaises(ValueError):
                validate_run(run, jobs, 'a' * 40, 101)
