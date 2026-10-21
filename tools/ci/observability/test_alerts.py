import unittest
from .alerts import detect
from .triage import classify


class WaitingSignalsTests(unittest.TestCase):
    def test_unavailable_runner_signal_never_means_quality_pass_or_known_root_cause(self):
        run=dict(status='queued',created_at='2026-10-19T10:00:00Z')
        job=dict(status='queued',created_at=run['created_at'],labels=['ubuntu-24.04'])
        rows=detect(run,[job],[],now='2026-10-19T11:00:00Z')
        self.assertEqual(2,len(rows));self.assertTrue(all(r['cause']=='UNVERIFIED' for r in rows))
        self.assertEqual('github-hosted-runner-or-approval-wait',rows[1]['kind'])
        self.assertEqual('BLOCKED',classify(run,[job])['outcome'])
