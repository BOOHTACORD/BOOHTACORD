"""Failed or interrupted phases cannot leave successful build metrics or private errors."""
import json
from pathlib import Path
import tempfile
import unittest
from .metrics import Metrics


class BuildMetricsTests(unittest.TestCase):
    def test_actual_stages_are_finite_and_success_requires_explicit_completion(self):
        with tempfile.TemporaryDirectory() as tmp:
            path=Path(tmp)/'build.json';metrics=Metrics(path,'a'*40)
            with metrics.stage('archive'):pass
            self.assertEqual('RUNNING',json.loads(path.read_text())['status'])
            metrics.complete({'api':'sha256:'+'b'*64,'web':'sha256:'+'c'*64})
            value=json.loads(path.read_text());self.assertEqual('PASS',value['status'])
            self.assertGreaterEqual(value['stages'][0]['seconds'],0)

    def test_failure_or_interrupt_contains_only_fixed_phase_and_status(self):
        for error in (ValueError('private-key-canary'),KeyboardInterrupt()):
            with tempfile.TemporaryDirectory() as tmp:
                path=Path(tmp)/'build.json';metrics=Metrics(path,'a'*40)
                with self.assertRaises(type(error)):
                    with metrics.stage('smoke'):raise error
                value=json.loads(path.read_text());self.assertEqual('FAIL',value['status'])
                self.assertNotIn('canary',path.read_text())

    def test_owned_storage_cleanup_is_required_before_release_metrics_pass(self):
        for cleanup in ({'status':'RUNNING','owned_resources_removed':False},
                        {'status':'FAIL','owned_resources_removed':True},
                        {'status':'PASS','owned_resources_removed':False}):
            with self.subTest(cleanup=cleanup), tempfile.TemporaryDirectory() as tmp:
                metrics=Metrics(Path(tmp)/'build.json','a'*40)
                with metrics.stage('package'):pass
                metrics.value['builder_storage']=cleanup
                with self.assertRaises(ValueError):
                    metrics.complete({'api':'sha256:'+'b'*64,'web':'sha256:'+'c'*64})
