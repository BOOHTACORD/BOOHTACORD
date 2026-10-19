"""Only successful transient PR captures may use a shorter review lifetime."""
import unittest
from .retention import days


class RetentionPolicyTests(unittest.TestCase):
    def test_release_receipts_packages_and_acceptance_keep_thirty_days_even_on_successful_pr(self):
        for role in ('release-proof', 'release-bundle', 'native-package', 'acceptance', 'failure-diagnostics'):
            with self.subTest(role=role):
                self.assertEqual(30, days(role, 'pull_request', 'refs/pull/12/merge', 'success'))

    def test_only_successful_transient_pull_request_captures_use_seven_days(self):
        self.assertEqual(7, days('synthetic-captures', 'pull_request', 'refs/pull/12/merge', 'success'))

    def test_master_tag_merge_queue_manual_qa_and_unknown_context_keep_thirty_days(self):
        for event, ref in [('push', 'refs/heads/master'), ('push', 'refs/tags/windows-v1.0.44'),
                           ('merge_group', 'refs/heads/gh-readonly-queue/master/1'),
                           ('workflow_dispatch', 'refs/heads/codex/test'),
                           ('workflow_run', 'refs/heads/master'), ('release', 'refs/tags/v1'),
                           ('pull_request', 'refs/heads/master'), ('unexpected', ''), (None, None)]:
            with self.subTest(event=event, ref=ref):
                self.assertEqual(30, days('synthetic-captures', event, ref, 'success'))

    def test_failed_cancelled_incomplete_or_unknown_status_cannot_shorten_diagnostics(self):
        for status in ('failure', 'cancelled', 'timed_out', 'in_progress', 'skipped', None, ''):
            with self.subTest(status=status):
                self.assertEqual(30, days('synthetic-captures', 'pull_request', 'refs/pull/12/merge', status))

    def test_unknown_role_is_not_silently_treated_as_temporary(self):
        for role in ('unknown', '', None):
            with self.assertRaises(ValueError): days(role, 'pull_request', 'refs/pull/12/merge', 'success')
