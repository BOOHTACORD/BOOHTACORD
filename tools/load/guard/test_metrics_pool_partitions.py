import unittest

from tools.load.guard.metrics import aggregate


class PoolPartitionMetricsTest(unittest.TestCase):
    def test_only_fixed_partition_and_state_labels_are_recorded(self):
        text = '''voice_platform_database_partition_connections{partition="main",state="max"} 16
voice_platform_database_partition_connections{partition="session",state="max"} 4
voice_platform_database_partition_connections{partition="main",state="acquired"} 16
voice_platform_database_partition_connections{partition="shared",state="idle"} 1
voice_platform_database_partition_connections{partition="main",state="max",user="private"} 99
voice_platform_database_partition_connections{partition="private",state="max"} 99
voice_platform_database_partition_connections{partition="main",state="private"} 99
voice_platform_database_partition_connections{partition="main",state="idle"} 1e
voice_platform_database_partition_connections{partition="main",state="total"} -1
voice_platform_database_partition_connections{partition="main",state="constructing"} 1e999
'''
        result = aggregate(text)
        self.assertEqual(result['voice_platform_database_partition_connections.main.max'], 16)
        self.assertEqual(result['voice_platform_database_partition_connections.session.max'], 4)
        self.assertEqual(result['voice_platform_database_partition_connections.main.acquired'], 16)
        self.assertEqual(result['voice_platform_database_partition_connections.shared.idle'], 1)
        self.assertNotIn('private', repr(result))
        self.assertNotIn('voice_platform_database_partition_connections.main.idle', result)
        self.assertNotIn('voice_platform_database_partition_connections.main.total', result)
        self.assertNotIn('voice_platform_database_partition_connections.main.constructing', result)
