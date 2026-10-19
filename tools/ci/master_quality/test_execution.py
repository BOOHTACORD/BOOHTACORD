"""Master scope receipts cannot survive missing gates, wrong source or retries."""
import json
import os
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch
from . import run
from . import test_context, test_validation


class MasterExecutionTests(unittest.TestCase):
    def fixture(self):
        return test_context.MasterContextTests().fixture()

    def test_real_source_and_reviewed_gate_results_bind_the_scope_receipt(self):
        env = self.fixture()
        from .test_validation import DIGEST
        for scope, selected in [('server', test_validation.server_needs()),
                                ('native', test_validation.NativeQualityTests().fixture())]:
            with self.subTest(scope=scope), tempfile.TemporaryDirectory() as tmp:
                root = Path(tmp).resolve()
                with patch.object(run, 'ROOT', root), patch.object(run, 'identity', return_value=('a' * 40, True)), \
                     patch.object(run, 'dependency_map', return_value=({}, DIGEST)), \
                     patch.dict(os.environ, {**env, 'MASTER_NEEDS': json.dumps(selected)}, clear=True), \
                     patch('sys.argv', ['master-quality', scope]):
                    self.assertEqual(0, run.main())
                value = json.loads((root / f'.out/ci/master-{scope}.json').read_text())
                self.assertEqual(('PASS', scope, 'a' * 40, '123', '1'),
                                 tuple(value[k] for k in ('status', 'scope', 'source_revision', 'run_id', 'run_attempt')))
                self.assertEqual(DIGEST, value['map_sha256'])
                self.assertNotIn('token', json.dumps(value).lower())

    def test_stale_pass_is_overwritten_on_missing_failed_foreign_or_dirty_inputs(self):
        from .test_validation import DIGEST
        for mutation in ('missing', 'failed', 'source', 'dirty', 'event', 'json'):
            env = self.fixture(); selected = test_validation.server_needs(); actual, clean = 'a' * 40, True
            if mutation == 'missing': selected.pop('web')
            if mutation == 'failed': selected['backend']['result'] = 'cancelled'
            if mutation == 'source': actual = 'b' * 40
            if mutation == 'dirty': clean = False
            if mutation == 'event': env['GITHUB_EVENT_NAME'] = 'pull_request'
            with self.subTest(mutation=mutation), tempfile.TemporaryDirectory() as tmp:
                root = Path(tmp).resolve(); path = root / '.out/ci/master-server.json'; path.parent.mkdir(parents=True)
                path.write_text('{"status":"PASS"}')
                with patch.object(run, 'ROOT', root), patch.object(run, 'identity', return_value=(actual, clean)), \
                     patch.object(run, 'dependency_map', return_value=({}, DIGEST)), \
                     patch.dict(os.environ, {**env, 'MASTER_NEEDS': 'invalid' if mutation == 'json' else json.dumps(selected)}, clear=True), \
                     patch('sys.argv', ['master-quality', 'server']):
                    self.assertEqual(1, run.main())
                self.assertEqual('FAIL', json.loads(path.read_text())['status'])
