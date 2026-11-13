"""The incident dashboard must reveal saturation of either database pool."""
import json
import unittest
from pathlib import Path


class PartitionDashboardTest(unittest.TestCase):
    def test_incident_pool_panel_includes_partition_saturation(self):
        root = Path(__file__).resolve().parents[3]
        dashboard = json.loads((root / 'docker/observability/dashboards/incidents.json').read_text(encoding='utf-8'))
        panel = next(item for item in dashboard['panels'] if item.get('id') == 13)
        expressions = [target['expr'] for target in panel['targets']]
        self.assertTrue(any('boohtacord_incident_database_pool_partition' in expr
                            and 'ignoring(stat)' in expr for expr in expressions))
