import hashlib
import json
import tempfile
from unittest.mock import patch
from pathlib import Path
import unittest

from . import build as catalog_builder
from .build import ROOT, OUT, build
from .extract import instruments, prometheus_name


class SignalCatalogTest(unittest.TestCase):
    def test_utf8_source_fingerprint_is_identical_for_crlf_and_lf_checkouts(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / 'source.go'
            lf = 'package synthetic\n// Синтетический источник\n'
            with patch.object(catalog_builder, 'ROOT', root):
                source.write_bytes(lf.encode('utf-8'))
                expected = catalog_builder.producer(source, 2)
                source.write_bytes(lf.replace('\n', '\r\n').encode('utf-8'))
                self.assertEqual(catalog_builder.producer(source, 2), expected)
                self.assertEqual(expected['sha256'], hashlib.sha256(lf.encode('utf-8')).hexdigest())

    def test_checked_in_inventory_matches_current_sources(self):
        self.assertEqual(build(), json.loads(OUT.read_text(encoding='utf-8')))

    def test_producer_order_is_stable_across_filesystem_enumeration(self):
        for signal in build()['signals']:
            paths = [owner['path'] for owner in signal['producer']]
            self.assertEqual(paths, sorted(paths), signal['source_name'])

    def test_units_counters_and_histogram_series_have_distinct_contracts(self):
        self.assertEqual(prometheus_name('boohtacord.http.duration', 'Float64Histogram', 's'), 'boohtacord_http_duration_seconds')
        self.assertEqual(prometheus_name('voice_platform_calls_total', 'Int64Counter', '1'), 'voice_platform_calls_total')
        self.assertEqual(prometheus_name('boohtacord.calls', 'Int64Counter', '1'), 'boohtacord_calls_total')
        self.assertEqual(prometheus_name('boohtacord_media_bitrate_kbps', 'Float64Histogram', '1'), 'boohtacord_media_bitrate_kbps')

    def test_extracts_whole_multiline_constructor_without_private_identifiers(self):
        source='''meter.Float64Histogram("duration", metric.WithUnit("s"), metric.WithExplicitBucketBoundaries(.1, 1))
prometheus.NewCounterVec(prometheus.CounterOpts{Name: "requests_total", Help: "safe aggregate"}, []string{"method", "status"})'''
        found=instruments(source)
        self.assertEqual(len(found), 2)
        self.assertEqual(found[0]['unit'], 's')
        self.assertEqual(found[1]['labels'], ['method', 'status'])
        self.assertNotIn('Help', found[1]['labels'])

    def test_dynamic_definitions_are_expanded_not_reported_as_prefix_series(self):
        catalog=build()
        names={s['source_name'] for s in catalog['signals']}
        self.assertIn('boohtacord_media_fps', names)
        self.assertIn('boohtacord.users.daily_active', names)
        self.assertNotIn('boohtacord_media_', names)
        self.assertNotIn('boohtacord.users.', names)
        self.assertIn('voice_platform_database_pool_acquired', names)
        self.assertNotIn('voice_platform_database_pool_', names)
        self.assertIn('voice.sfu_revocation.attempt', names)
        self.assertIn('message.send.server', names)
        self.assertIn('app.screen.viewer.started', names)

    def test_every_signal_has_owner_consumer_and_honest_delivery_contract(self):
        catalog=build()
        self.assertGreater(len(catalog['signals']), 100)
        for signal in catalog['signals']:
            for key in ('scenario', 'producer', 'source_name', 'exported_name', 'type', 'unit', 'attributes_or_labels', 'frequency', 'storage', 'consumers', 'decision', 'delivery'):
                self.assertIn(key, signal, signal['source_name'])
            self.assertTrue(signal['producer'])
            self.assertNotEqual(signal['delivery']['runtime_status'], 'PASS')
            for producer in signal['producer']:
                self.assertTrue((ROOT / producer['path']).is_file())
                self.assertEqual(len(producer['sha256']), 64)
            if signal['type'] != 'span/event':
                self.assertFalse({'user.id', 'session.id', 'app.visit.id', 'app.flow.id', 'trace_id', 'request_id'} & set(signal['attributes_or_labels']))
            if signal['delivery']['transport'] == 'private-prometheus':
                self.assertIn('private', signal['delivery']['boundary'])
                self.assertNotIn('OTLP', signal['delivery']['boundary'])

    def test_native_custom_pool_counters_keep_counter_semantics_and_seconds(self):
        signals={s['source_name']:s for s in build()['signals'] if s['delivery']['transport']=='private-prometheus'}
        wait=signals['voice_platform_database_pool_empty_acquire_wait_seconds_total']
        self.assertEqual(wait['type'], 'Counter')
        self.assertEqual(wait['unit'], 's')
        self.assertEqual(signals['voice_platform_database_pool_acquired']['type'], 'Gauge')

    def test_product_scenarios_and_limits_are_explicit(self):
        catalog=build()
        required={'auth', 'messages', 'attachments', 'search', 'social', 'admin', 'voice', 'screen', 'presence', 'desktop_update', 'telemetry', 'database', 'storage', 'livekit', 'realtime', 'usage'}
        self.assertEqual({s['id'] for s in catalog['scenarios']}, required)
        self.assertTrue(catalog['boundaries']['sampled_tables_are_not_counters'])
        self.assertIn('NOT_RUN', catalog['boundaries']['runtime_evidence'])


if __name__ == '__main__':
    unittest.main()
