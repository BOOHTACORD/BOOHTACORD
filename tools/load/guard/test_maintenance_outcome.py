import unittest

from tools.load.guard.metrics import aggregate


class MaintenanceMetricsTest(unittest.TestCase):
    def test_keeps_only_fixed_observer_outcomes(self):
        result = aggregate('''voice_platform_maintenance_observer_reads_total{outcome="success"} 3
voice_platform_maintenance_observer_reads_total{outcome="failure"} 2
voice_platform_maintenance_observer_reads_total{outcome="private"} 99
''')
        self.assertEqual(result['voice_platform_maintenance_observer_reads_total.outcome.success'], 3)
        self.assertEqual(result['voice_platform_maintenance_observer_reads_total.outcome.failure'], 2)
        self.assertNotIn('private', repr(result))


if __name__ == '__main__':
    unittest.main()
