"""PR, foreign, stale or dirty checkouts never become master-quality evidence."""
import unittest
from . import context


class MasterContextTests(unittest.TestCase):
    def fixture(self):
        return {'GITHUB_ACTIONS': 'true', 'GITHUB_REPOSITORY': 'BOOHTACORD/BOOHTACORD',
                'GITHUB_REF': 'refs/heads/master', 'GITHUB_EVENT_NAME': 'push',
                'GITHUB_SHA': 'a' * 40, 'GITHUB_RUN_ID': '123', 'GITHUB_RUN_ATTEMPT': '1'}

    def test_only_real_exact_source_master_push_or_dispatch_is_accepted(self):
        for event in ('push', 'workflow_dispatch'):
            env = self.fixture(); env['GITHUB_EVENT_NAME'] = event
            self.assertEqual({'source_revision': 'a' * 40, 'run_id': '123', 'run_attempt': '1'},
                             context.validate(env, 'a' * 40, True))

    def test_pr_merge_queue_fork_branch_or_non_actions_context_fails(self):
        for field, value in [('GITHUB_EVENT_NAME', 'pull_request'), ('GITHUB_EVENT_NAME', 'merge_group'),
                             ('GITHUB_EVENT_NAME', 'workflow_run'), ('GITHUB_REPOSITORY', 'fork/BOOHTACORD'),
                             ('GITHUB_REF', 'refs/pull/1/merge'), ('GITHUB_REF', 'refs/heads/codex/test'),
                             ('GITHUB_ACTIONS', 'false'), ('GITHUB_RUN_ID', ''), ('GITHUB_RUN_ATTEMPT', '0')]:
            env = self.fixture(); env[field] = value
            with self.subTest(field=field, value=value), self.assertRaises(ValueError): context.validate(env, 'a' * 40, True)

    def test_source_mismatch_missing_sha_or_nonboolean_clean_cannot_attest(self):
        for actual, clean in [('b' * 40, True), ('a' * 40, False), ('a' * 40, 1)]:
            with self.subTest(actual=actual, clean=clean), self.assertRaises(ValueError):
                context.validate(self.fixture(), actual, clean)
        env = self.fixture(); env['GITHUB_SHA'] = ''
        with self.assertRaises(ValueError): context.validate(env, 'a' * 40, True)
