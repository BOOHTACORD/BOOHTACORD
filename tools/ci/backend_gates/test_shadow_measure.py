"""Only complete execution-bound reports may replace a comparison's FAIL."""
import contextlib
import io
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
from . import shadow_measure as measure
from .test_shadow import fixture, SOURCE


class MeasureTests(unittest.TestCase):
    def invoke(self, root, args=(), source=SOURCE, api=None, needs=None):
        with patch.object(measure, 'ROOT', root), \
             patch.object(measure, 'checked_source', side_effect=source if isinstance(source, Exception) else None,
                          return_value=source), \
             patch.object(measure, 'read_api', side_effect=api) as read_api, \
             patch('sys.argv', ['shadow_measure', *args]), \
             patch.dict(os.environ, GITHUB_ACTIONS='true', GITHUB_RUN_ID='123', GITHUB_RUN_ATTEMPT='1',
                        BACKEND_SHADOW_NEEDS=json.dumps(needs or fixture()[2])), \
             contextlib.redirect_stdout(io.StringIO()):
            measure.main()
        return read_api

    def inputs(self, root):
        run, jobs, needs, old, parts, fanin = fixture()
        folder = root/'.out/ci/backend-shadow-inputs'
        for relative, value in [('legacy/backend-shadow-legacy.json', old),
                                ('fan-in/backend-fan-in.json', fanin),
                                *[('parts/'+part['profile']+'.json', part) for part in parts]]:
            path = folder/relative; path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(json.dumps(value))
        output = root/'.out/ci/backend-shadow.json'
        output.write_text('{"status":"PASS"}')
        return run, jobs, needs, output

    def test_prepare_invalidates_stale_pass_without_api_or_downloads(self):
        with tempfile.TemporaryDirectory() as name:
            root = Path(name); _, _, _, output = self.inputs(root)
            api = self.invoke(root, ['--prepare-only'])
            api.assert_not_called()
            self.assertEqual(json.loads(output.read_text())['status'], 'FAIL')

    def test_failed_source_preflight_invalidates_stale_pass(self):
        with tempfile.TemporaryDirectory() as name:
            root = Path(name); _, _, _, output = self.inputs(root)
            with self.assertRaises(ValueError):
                self.invoke(root, source=ValueError('controlled-source-failure'))
            self.assertEqual(json.loads(output.read_text())['status'], 'FAIL')

    def test_complete_files_and_exact_run_metadata_allow_pass(self):
        with tempfile.TemporaryDirectory() as name:
            root = Path(name); run, jobs, _, output = self.inputs(root)
            api = self.invoke(root, api=[run, jobs])
            self.assertEqual([c.args[0] for c in api.call_args_list],
                             ['/actions/runs/123', '/actions/runs/123/jobs?filter=latest&per_page=100'])
            self.assertEqual(json.loads(output.read_text())['status'], 'PASS')

    def test_failure_missing_or_foreign_inputs_and_unavailable_metadata_keep_fail(self):
        for change in ('needs', 'missing', 'foreign', 'api'):
            with self.subTest(change=change), tempfile.TemporaryDirectory() as name:
                root = Path(name); run, jobs, needs, output = self.inputs(root)
                if change == 'needs': needs['legacy']['result'] = 'failure'
                if change == 'missing': (root/'.out/ci/backend-shadow-inputs/parts/load.json').unlink()
                if change == 'foreign': run['head_sha'] = 'b'*40
                api = RuntimeError('controlled-unavailable') if change == 'api' else [run, jobs]
                with self.assertRaises((ValueError, RuntimeError)):
                    self.invoke(root, api=api, needs=needs)
                self.assertEqual(json.loads(output.read_text())['status'], 'FAIL')
