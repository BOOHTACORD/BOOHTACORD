"""Roster dashboards must expose missing data and bounded operational signals."""
import json
from pathlib import Path
import unittest
import yaml

ROOT = Path(__file__).resolve().parents[3]


class RosterObservabilityTest(unittest.TestCase):
    def test_fleet_dashboard_uses_live_websocket_subscriber_metric(self):
        dashboard = json.loads((ROOT / 'docker/observability/fleet/dashboards/voice-roster.json').read_text(encoding='utf-8'))
        expressions = '\n'.join(target['expr'] for panel in dashboard['panels'] for target in panel['targets'])
        self.assertIn('voice_roster_ws_subscribers', expressions)
        self.assertNotIn('voice_roster_streams_active', expressions)

    def test_generated_dashboard_rules_have_unique_series_names(self):
        from .promql import main
        main()
        rules = yaml.safe_load((ROOT / '.out/voice-roster/dashboard-rules.yaml').read_text())['groups'][0]['rules']
        names = [rule['record'] for rule in rules]
        self.assertEqual(len(names), len(set(names)))
        self.assertIn('fleet_roster_panel_2_A', names)

    def test_dashboard_has_bounded_signals_and_neutral_missing_data(self):
        dashboard = json.loads((ROOT / 'docker/observability/dashboards/voice-roster.json').read_text(encoding='utf-8'))
        self.assertEqual(dashboard['uid'], 'boohtacord-voice-roster')
        occupied = set()
        expressions = []
        for panel in dashboard['panels']:
            self.assertEqual(panel['fieldConfig']['defaults']['noValue'], 'Нет данных')
            g = panel['gridPos']
            cells = {(x, y) for x in range(g['x'], g['x'] + g['w'])
                     for y in range(g['y'], g['y'] + g['h'])}
            self.assertFalse(cells & occupied)
            occupied |= cells
            for target in panel['targets']:
                expressions.append(target['expr'])
        query = '\n'.join(expressions)
        for name in ('voice_roster_failures_total', 'voice_roster_ws_delivery_seconds_bucket',
                     'voice_roster_ws_subscribers', 'voice_roster_ws_delivery_total',
                     'voice_roster_ws_initial_total', 'voice_roster_ws_refresh_total',
                     'sfu_room_service_seconds_bucket', 'sfu_room_service_calls_total',
                     'voice_presence_gate_total', 'voice_roster_ws_last_success_timestamp_seconds'):
            self.assertIn(name, query)
        for legacy in ('voice_roster_streams_active', 'voice_roster_stream_ends_total',
                       'voice_roster_initial_seconds', 'voice_roster_initial_total'):
            self.assertNotIn(legacy, query)
        for name in ('sfu_room_service_transport_failures_total', 'sfu_room_service_http_failures_total'):
            self.assertIn(name, query)
        self.assertIn('histogram_quantile(0.95', query)
        self.assertNotIn('or vector(0)', query)
        for private_label in ('user_id', 'channel_id', 'lease_id', 'session_id', 'room_id'):
            self.assertNotIn(private_label, query)

    def test_alerts_are_wired_private_and_sustained(self):
        rules = (ROOT / 'docker/observability/voice-roster-alerts.yaml').read_text()
        self.assertEqual(rules.count('      - alert:'), 4)
        self.assertEqual(rules.count('        for: 5m'), 4)
        self.assertIn('voice_roster_ws_subscribers', rules)
        self.assertIn('voice_roster_ws_initial_total', rules)
        self.assertIn('voice_roster_ws_delivery_total', rules)
        self.assertIn('voice_roster_ws_observation_enabled', rules)
        self.assertNotIn('voice_roster_streams_active', rules)
        self.assertIn('unless on(service_name)', rules)
        self.assertNotIn('or vector(0)', rules)
        for file in ('compose.yaml', 'prometheus.yaml'):
            self.assertIn('voice-roster-alerts.yaml', (ROOT / 'docker/observability' / file).read_text())
        runbook = (ROOT / 'docs/operations/voice-roster.md').read_text()
        for stage in ('visibility_initial', 'presence_room_list', 'visibility_recheck',
                      'NO_CONFIG_CHANGE', 'NOT_RUN', 'rollback'):
            self.assertIn(stage, runbook)


if __name__ == '__main__':
    unittest.main()
