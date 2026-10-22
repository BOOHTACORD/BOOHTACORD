"""Private delivery must expose health without promoting trace identities to labels."""
from pathlib import Path
import unittest

import yaml

ROOT = Path(__file__).resolve().parents[3]


class DeliveryConfigTest(unittest.TestCase):
    def setUp(self):
        self.collector = yaml.safe_load((ROOT / 'docker/observability/collector.yaml').read_text())
        self.prometheus = yaml.safe_load((ROOT / 'docker/observability/prometheus.yaml').read_text())

    def test_resource_labels_are_explicitly_bounded(self):
        exporter = self.collector['exporters']['prometheus']
        self.assertFalse(exporter.get('resource_to_telemetry_conversion', {}).get('enabled', False))
        self.assertEqual(exporter['resource_constant_labels']['included'], ['service.name', 'service.version', 'service.instance.id'])
        self.assertTrue(exporter['without_scope_info'])
        job = next(j for j in self.prometheus['scrape_configs'] if j['job_name'] == 'boohtacord-otel-metrics')
        self.assertTrue(any(r.get('action') == 'drop' and 'target_info' in r.get('regex', '') for r in job['metric_relabel_configs']))

    def test_health_and_application_metrics_are_separate_targets(self):
        jobs = {j['job_name']: j for j in self.prometheus['scrape_configs']}
        self.assertEqual(jobs['boohtacord-collector']['static_configs'][0]['targets'], ['collector:8888'])
        telemetry = self.collector['service']['telemetry']['metrics']
        endpoint = telemetry['readers'][0]['pull']['exporter']['prometheus']
        self.assertEqual(endpoint, {'host': '0.0.0.0', 'port': 8888})
        compose = yaml.safe_load((ROOT / 'docker/observability/compose.yaml').read_text())
        self.assertFalse(any(':8888' in str(p) for p in compose['services']['collector']['ports']))

    def test_outage_budget_and_trace_contents_are_preserved(self):
        exporter = self.collector['exporters']['otlphttp/tempo']
        self.assertEqual(exporter['sending_queue']['queue_size'], 128)
        self.assertEqual(exporter['retry_on_failure']['max_elapsed_time'], '30s')
        self.assertEqual(self.collector['service']['pipelines']['traces']['processors'], ['memory_limiter', 'batch'])

    def test_optional_scope_queries_have_a_finite_reviewed_budget(self):
        tempo = yaml.safe_load((ROOT / 'docker/observability/tempo.yaml').read_text())
        self.assertEqual(tempo['query_frontend']['max_query_expression_size_bytes'], 8192)


if __name__ == '__main__':
    unittest.main()
