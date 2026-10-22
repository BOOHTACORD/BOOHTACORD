"""Remote monitor has no dependency on the application host's Docker networks."""
import json
from pathlib import Path
import shutil
import subprocess
import unittest

import yaml

ROOT = Path(__file__).resolve().parents[3]


class RemoteMonitorTest(unittest.TestCase):
    def test_remote_scrapes_only_existing_private_monitor_services(self):
        config = yaml.safe_load((ROOT / 'docker/observability/prometheus.remote.yaml').read_text())
        self.assertNotIn('rule_files', config)
        jobs = {job['job_name']: job for job in config['scrape_configs']}
        self.assertEqual(set(jobs), {'boohtacord-otel-metrics', 'boohtacord-collector', 'boohtacord-tempo', 'boohtacord-prometheus'})
        targets = [target for job in jobs.values() for group in job['static_configs'] for target in group['targets']]
        self.assertEqual(set(targets), {'collector:8889', 'collector:8888', 'tempo:3200', 'localhost:9090'})
        self.assertEqual(config['global']['scrape_interval'], '15s')
        self.assertFalse(any('livekit' in target or 'api' in target for target in targets))

    def test_application_exporter_privacy_filter_matches_colocated_profile(self):
        remote = yaml.safe_load((ROOT / 'docker/observability/prometheus.remote.yaml').read_text())
        local = yaml.safe_load((ROOT / 'docker/observability/prometheus.yaml').read_text())
        def application(config):
            return next(job for job in config['scrape_configs'] if job['job_name'] == 'boohtacord-otel-metrics')
        self.assertEqual(application(remote), application(local))
        filters = application(remote)['metric_relabel_configs']
        self.assertIn({'source_labels': ['__name__'], 'regex': 'target_info|otel_scope_info', 'action': 'drop'}, filters)

    @unittest.skipUnless(shutil.which('docker'), 'Docker Compose is required for actual merge rendering')
    def test_actual_compose_merge_preserves_pins_bindings_data_and_retention(self):
        result = subprocess.run(['docker', 'compose', '-f', 'docker/observability/compose.yaml', '-f', 'docker/observability/compose.remote.yaml', 'config', '--format', 'json'], cwd=ROOT, text=True, capture_output=True, timeout=20)
        self.assertEqual(result.returncode, 0, result.stderr)
        rendered = json.loads(result.stdout)
        services = rendered['services']
        self.assertEqual(set(services), {'collector', 'tempo', 'prometheus'})
        for service, image, port in [('collector', 'otel/opentelemetry-collector:0.161.0', 4318), ('tempo', 'grafana/tempo:2.10.3', 3200), ('prometheus', 'prom/prometheus:v3.11.2', 9090)]:
            config = services[service]
            self.assertEqual(config['image'], image)
            self.assertEqual(config['ports'][0]['host_ip'], '127.0.0.1')
            self.assertEqual(config['ports'][0]['target'], port)
            self.assertEqual(set(config['networks']), {'default'})
        self.assertFalse(any(net.get('external') for net in rendered['networks'].values()))
        mounts = services['prometheus']['volumes']
        self.assertEqual(len(mounts), 2)
        self.assertTrue(next(m for m in mounts if m['type'] == 'bind')['source'].endswith('/prometheus.remote.yaml'))
        self.assertTrue(next(m for m in mounts if m['type'] == 'bind')['read_only'])
        self.assertEqual(next(m for m in mounts if m['type'] == 'volume')['source'], 'prometheus-data')
        self.assertIn('--storage.tsdb.retention.time=7d', services['prometheus']['command'])
        self.assertIn('--storage.tsdb.retention.size=2GB', services['prometheus']['command'])
        self.assertEqual(set(rendered['volumes']), {'tempo-data', 'prometheus-data'})


if __name__ == '__main__':
    unittest.main()
