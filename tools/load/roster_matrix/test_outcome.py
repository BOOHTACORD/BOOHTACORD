import unittest
from tools.load.roster_matrix.outcome import classify


class OutcomeTest(unittest.TestCase):
    def report(self):
        return {'Outcome': 'PASS', 'StopReason': 'bounded_initial_and_steady',
                'Accounts': 2, 'Rooms': 0, 'Mode': 'candidate',
                'Measurements': {name: {'Count': 2} for name in ('ready', 'roster', 'maintenance')},
                'Resources': [{'MetricsStatus': 'AVAILABLE', 'Metrics': {}},
                              {'MetricsStatus': 'AVAILABLE', 'Metrics': {
                                  'voice_platform_realtime_connections_active.scope.authenticated': 2}}]}

    def test_dirty_source_can_only_be_a_smoke(self):
        self.assertEqual(classify(self.report(), 0, 'candidate', 2, 0, False), 'SMOKE_PASS')
        self.assertEqual(classify(self.report(), 0, 'candidate', 2, 0, True), 'PASS')

    def test_shared_source_report_cannot_pass_as_independent(self):
        report = self.report()
        report['SourceProfile'] = 'independent'
        self.assertEqual(classify(report, 0, 'candidate', 2, 0, True, same_source=True), 'FAIL')
        report['SourceProfile'] = 'shared'
        self.assertEqual(classify(report, 0, 'candidate', 2, 0, True, same_source=True), 'PASS')

    def test_missing_snapshots_resources_or_driver_failure_never_pass(self):
        report = self.report()
        report['Measurements']['roster']['Count'] = 1
        self.assertEqual(classify(report, 0, 'candidate', 2, 0, True), 'FAIL')
        report = self.report()
        report['Resources'] = []
        self.assertEqual(classify(report, 0, 'candidate', 2, 0, True), 'FAIL')
        report = self.report()
        report['Resources'][1]['Metrics'] = {}
        self.assertEqual(classify(report, 0, 'candidate', 2, 0, True), 'FAIL')
        self.assertEqual(classify(self.report(), 1, 'candidate', 2, 0, True), 'FAIL')
        self.assertEqual(classify(self.report(), 0, 'baseline', 2, 0, True), 'FAIL')

    def test_change_profile_requires_every_actor_and_explicit_scope(self):
        report = self.report()
        self.assertEqual(classify(report, 0, 'candidate', 2, 0, True, maintenance_change=True), 'FAIL')
        report['StopReason'] = 'bounded_initial_change_and_steady'
        report['Measurements']['maintenance_change'] = {'Count': 1}
        self.assertEqual(classify(report, 0, 'candidate', 2, 0, True, maintenance_change=True), 'FAIL')
        report['Measurements']['maintenance_change']['Count'] = 2
        self.assertEqual(classify(report, 0, 'candidate', 2, 0, False, maintenance_change=True), 'SMOKE_PASS')

    def test_message_profile_requires_full_fanout_without_duplicates_or_slow_p95(self):
        report = self.report()
        self.assertEqual(classify(report, 0, 'candidate', 2, 0, False, messages=3), 'FAIL')
        report['Message'] = {'Messages': 3, 'Duplicates': 0, 'Deliveries': {'Count': 6, 'P95MS': 500},
                             'Batches': [{'Count': 2}] * 3}
        self.assertEqual(classify(report, 0, 'candidate', 2, 0, False, messages=3), 'SMOKE_PASS')
        report['Message']['Deliveries']['P95MS'] = 501
        self.assertEqual(classify(report, 0, 'candidate', 2, 0, False, messages=3), 'FAIL')
        report['Message']['Deliveries']['P95MS'] = 1
        report['Message']['Duplicates'] = 1
        self.assertEqual(classify(report, 0, 'candidate', 2, 0, False, messages=3), 'FAIL')
        report['Message']['Duplicates'] = 0
        report['Message']['Batches'] = [{'Count': 2}] * 2
        self.assertEqual(classify(report, 0, 'candidate', 2, 0, False, messages=3), 'FAIL')

    def test_warmup_must_match_the_requested_workload(self):
        report = self.report()
        report['Message'] = {'Messages': 1, 'Duplicates': 0, 'Deliveries': {'Count': 2, 'P95MS': 1},
                             'Batches': [{'Count': 2}]}
        report['MessageWarmupMS'] = 0
        self.assertEqual(classify(report, 0, 'candidate', 2, 0, False, messages=1, warmup_ms=1000), 'FAIL')
        report['MessageWarmupMS'] = 1000
        self.assertEqual(classify(report, 0, 'candidate', 2, 0, False, messages=1, warmup_ms=1000), 'SMOKE_PASS')
