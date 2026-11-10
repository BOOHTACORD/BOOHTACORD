import unittest

from tools.load.guard.metrics import aggregate


class ScopedConnectionMetricsTest(unittest.TestCase):
    def test_only_fixed_scope_labels_are_reported_separately(self):
        data = '''voice_platform_realtime_connections_active{scope="public"} 2
voice_platform_realtime_connections_active{scope="authenticated"} 3
voice_platform_realtime_connections_active{scope="public",account="sensitive"} 9
'''
        result = aggregate(data)
        self.assertEqual(result['voice_platform_realtime_connections_active.scope.public'], 2)
        self.assertEqual(result['voice_platform_realtime_connections_active.scope.authenticated'], 3)
        self.assertNotIn('sensitive', repr(result))
        self.assertEqual(result['voice_platform_realtime_connections_active'], 14)
