"""Contracts for navigable, bounded and identity-safe trace views."""
import json
import unittest

from tools.verify.trace_dashboard.fixture import DashboardFixture


class TracesDashboardTest(DashboardFixture):
    def test_identity_filters_are_tempo_labels_and_default_to_all(self):
        variables = {v['name']: v for v in self.dashboard['templating']['list']}
        for name in ('user', 'session'):
            variable = variables[name]
            self.assertEqual(variable['query']['label'], name + '.id')
            self.assertEqual(variable['query']['type'], 1)
            self.assertEqual(variable['current']['value'], '$__all')
            self.assertTrue(variable['includeAll'])

    def test_identity_filter_retains_opaque_value_and_stable_grouping(self):
        variable = self.dashboard['templating']['list'][0]
        self.assertEqual(variable['regex'], '')
        self.assertEqual(variable['query']['label'], 'user.id')
        panel = self.panels[21]
        self.assertIn('span.user.name', panel['targets'][0]['query'])
        group = next(t for t in panel['transformations'] if t['id'] == 'groupBy')
        self.assertEqual(group['options']['fields']['user.name']['operation'], 'aggregate')
        self.assertEqual(group['options']['fields']['user.id']['operation'], 'groupby')
        self.assertFalse(any(t['id'] == 'groupBy' for t in self.panels[33]['transformations']))

    def test_session_summary_groups_spans_and_links_to_filtered_timeline(self):
        panel = self.panels[21]
        target = panel['targets'][0]
        self.assertEqual(target['tableType'], 'spans')
        self.assertEqual(target['limit'], 500)
        for identity in ('user', 'session'):
            self.assertIn('span.' + identity + '.id', target['query'])
            self.assertIn('${' + identity + ':regex}', target['query'])
        group = next(t for t in panel['transformations'] if t['id'] == 'groupBy')
        # Tempo 2.10 returns selected attribute keys without their TraceQL scope.
        self.assertEqual(group['options']['fields']['session.id']['operation'], 'groupby')
        self.assertEqual(group['options']['fields']['user.id']['operation'], 'groupby')
        encoded = json.dumps(panel, ensure_ascii=False)
        self.assertIn('var-session=${__value.raw}', encoded)
        self.assertIn('выборк', panel['description'])

    def test_clients_are_linked_through_verified_server_spans(self):
        query = self.panels[22]['targets'][0]['query']
        for platform in ('web', 'android', 'ios', 'windows', 'macos'):
            self.assertIn(platform, query)
        self.assertIn('} &&', query)
        self.assertIn('span.user.id', query)

    def test_websocket_lifetime_is_not_a_slow_http_request(self):
        query = self.panels[24]['targets'][0]['query']
        self.assertIn('span.http.route != "GET /api/v1/realtime"', query)
        self.assertIn('duration > 1s', query)

    def test_background_and_old_traces_remain_available_but_collapsed(self):
        row = self.panels[29]
        self.assertTrue(row['collapsed'])
        self.assertGreaterEqual(len(row['panels']), 2)
        self.assertTrue(any('span.user.id = nil' in p['targets'][0]['query']
                            for p in row['panels'] if p.get('targets')))

    def test_media_samples_keep_identity_units_and_missing_values(self):
        panel = self.panels[33]
        query = panel['targets'][0]['query']
        self.assertIn('name = "media.sample"', query)
        for field in ('user.id', 'session.id', 'media.rtt_ms', 'media.bitrate_kbps', 'media.encoded_fps',
                      'media.decoded_fps', 'media.packet_loss_percent', 'media.packet_loss_window_ms',
                      'media.target_resolution', 'media.target_fps', 'media.frame_width', 'media.frame_height'):
            self.assertIn('.' + field, query)
        for identity in ('user', 'session'):
            self.assertIn('${' + identity + ':regex}', query)
        units = {o['matcher']['options']: next((p['value'] for p in o['properties'] if p['id'] == 'unit'), None)
                 for o in panel['fieldConfig']['overrides']}
        self.assertEqual(units['media.packet_loss_percent'], 'percent')
        self.assertEqual(units['media.rtt_ms'], 'ms')

    def test_fps_and_loss_preserve_missing_without_stale_green_ratio(self):
        panel = self.panels[33]
        self.assertFalse(any(t['id'] == 'calculateField' for t in panel['transformations']))
        overrides = {o['matcher']['options']: {p['id']: p['value'] for p in o['properties']}
                     for o in panel['fieldConfig']['overrides']}
        self.assertEqual(overrides['media.packet_loss_percent']['mappings'][0]['options']['result']['text'], 'нет данных')
        self.assertNotIn('thresholds', overrides['media.packet_loss_percent'])
        self.assertIn('.media.encoded_fps', panel['targets'][0]['query'])
        self.assertIn('.media.target_fps', panel['targets'][0]['query'])


if __name__ == '__main__':
    unittest.main()
