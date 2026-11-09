import unittest
from tools.load.roster_matrix.public_outcome import classify_public


class PublicOutcomeTest(unittest.TestCase):
    def report(self):
        return {'Outcome': 'PASS', 'StopReason': 'bounded_initial_and_steady', 'Mode': 'candidate',
                'Guests': 100, 'Measurements': {'ready': {'Count': 100}, 'maintenance': {'Count': 100}, 'roster': {'Count': 0}},
                'Resources': [{'MetricsStatus': 'AVAILABLE', 'Metrics': {}},
                              {'MetricsStatus': 'AVAILABLE', 'Metrics': {'voice_platform_realtime_connections_active.scope.public': 100}}]}

    def test_requires_all_guests_and_public_scope_measurement(self):
        self.assertEqual(classify_public(self.report(), 0, 'candidate', 100, False), 'SMOKE_PASS')
        report = self.report()
        report['Measurements']['maintenance']['Count'] = 99
        self.assertEqual(classify_public(report, 0, 'candidate', 100, True), 'FAIL')
        report = self.report()
        report['Resources'][1]['Metrics'] = {}
        self.assertEqual(classify_public(report, 0, 'candidate', 100, True), 'FAIL')

    def test_baseline_has_no_fabricated_socket_ready(self):
        report = self.report()
        report['Mode'] = 'baseline'
        report['Measurements']['ready']['Count'] = 0
        report['Resources'][1]['Metrics'] = {}
        self.assertEqual(classify_public(report, 0, 'baseline', 100, True), 'PASS')
