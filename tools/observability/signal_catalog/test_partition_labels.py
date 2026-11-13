"""Partition telemetry labels stay explicit and low-cardinality."""
import unittest

from .labels import otel_labels


class PartitionLabelsTest(unittest.TestCase):
    def test_partition_labels_are_recorded(self):
        self.assertEqual(
            otel_labels('boohtacord.incident.database.pool.partition'),
            ['partition', 'stat'],
        )
