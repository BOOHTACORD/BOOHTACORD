import unittest
from .api import Api
from .collect import collect_cohort


class FakeApi:
    def __init__(self):
        self.calls = []

    def pages(self, path, key):
        self.calls.append(path)
        if key == 'workflow_runs':
            return [{'id': 3, 'status': 'in_progress'},
                    {'id': 2, 'status': 'completed', 'run_attempt': 2,
                     'head_sha': 'a' * 40, 'event': 'pull_request'}]
        if key == 'jobs':
            return [{'id': 10, 'name': 'x'}]
        return []


class CollectTests(unittest.TestCase):
    def test_get_only_fixed_public_repo_and_no_custom_host_redirects(self):
        api = Api(token=None, max_requests=1)
        for path in ['https://evil.example', '//evil.example', '/../../user', '/actions/runs?x=\n']:
            with self.assertRaises(ValueError):
                api.get(path)
        self.assertEqual(api.requests, 0)

    def test_request_budget_never_yields_partial_silent_success(self):
        api = Api(token=None, max_requests=0)
        with self.assertRaisesRegex(RuntimeError, 'budget'):
            api.get('/actions/runs')

    def test_jobs_from_every_attempt_are_requested_and_inprogress_excluded(self):
        api = FakeApi()
        result = collect_cohort(api, 'ci_pr', 1, '.', artifacts=False)
        self.assertEqual(len(result), 1)
        self.assertEqual(len(result[0]['attempts']), 2)
        self.assertTrue(any('/attempts/1/jobs' in p for p in api.calls))
        self.assertTrue(any('/attempts/2/jobs' in p for p in api.calls))

    def test_paginated_metadata_must_match_total_count(self):
        api = Api()
        replies = iter([{'total_count': 2, 'jobs': [{'id': 1}]},
                        {'total_count': 2, 'jobs': [{'id': 2}]}])
        api.get = lambda path: next(replies)
        self.assertEqual(api.pages('/actions/runs/1/jobs', 'jobs'), [{'id': 1}, {'id': 2}])

    def test_truncated_metadata_cannot_silently_pass(self):
        api = Api()
        replies = iter([{'total_count': 2, 'jobs': [{'id': 1}]}, {'total_count': 2, 'jobs': []}])
        api.get = lambda path: next(replies)
        with self.assertRaisesRegex(RuntimeError, 'incomplete'):
            api.pages('/actions/runs/1/jobs', 'jobs')
