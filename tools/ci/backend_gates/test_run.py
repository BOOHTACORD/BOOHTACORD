"""Actual entrypoints retain all old commands, fail/skip paths cannot pass."""
import json
import os
from pathlib import Path
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch
from tools.ci.native import backend
from tools.ci.receipts import run as receipts
from . import run as runner
from .test_results import SOURCE, fixture


class RunnerTests(unittest.TestCase):
    def test_database_always_uncached_and_verifier_runs_even_after_test_failure(self):
        for test_code, verify_code in ((0,0), (1,0), (0,1)):
            with tempfile.TemporaryDirectory() as name, patch.object(backend,'ROOT',Path(name)), \
                 patch.object(backend,'run',side_effect=[SimpleNamespace(returncode=0),
                    SimpleNamespace(returncode=test_code),SimpleNamespace(returncode=verify_code),SimpleNamespace(returncode=0)]) as run:
                if test_code or verify_code:
                    with self.assertRaises(SystemExit): backend.run_profile('database')
                else: backend.run_profile('database')
                self.assertEqual(run.call_args_list[0].args, ('go','run','./cmd/check-test-database'))
                self.assertEqual(run.call_args_list[1].args, ('go','test','-json','-count=1','./...'))
                self.assertIn('tools/verify/go_test_events/verify-go-test-events.py', run.call_args_list[2].args)
                if not test_code and not verify_code:
                    self.assertEqual(run.call_args_list[3].args[1:], ('-m','tools.qa.installation_telemetry.run'))
                else:self.assertEqual(run.call_count,3)

    def test_static_preserves_vet_and_build_and_load_preserves_five_profiles(self):
        with patch.object(backend,'run') as run: backend.run_profile('static')
        self.assertEqual([c.args for c in run.call_args_list], [('go','vet','./...'), ('go','build','./...')])
        with patch.object(runner,'run') as run: runner.load_smoke()
        calls = [c.args for c in run.call_args_list]
        self.assertIn('tools.load.screen_share_matrix.test_planner', calls[0])
        profiles = [c[c.index('--profile')+1] for c in calls[1:]]
        self.assertEqual(profiles, ['normal','reconnect','uploads','nat_auth','faults'])
        self.assertIn('40', calls[-1])
        self.assertIn('--upload-bytes', calls[3])

    def test_failure_overwrites_stale_success_without_private_exception(self):
        with tempfile.TemporaryDirectory() as name:
            root=Path(name); target=root/'.out/ci/backend-parts/static.json'; target.parent.mkdir(parents=True)
            target.write_text('{"status":"PASS"}')
            with patch.object(runner,'ROOT',root), patch.object(runner,'checked_source',return_value=SOURCE), \
                 patch.object(runner,'require_version'), patch.object(runner,'output',return_value='go version go1.26.4 darwin/arm64'), \
                 patch.object(runner.backend,'run_profile',side_effect=RuntimeError('private body')):
                with self.assertRaises(RuntimeError): runner.execute('static')
            self.assertEqual(json.loads(target.read_text())['status'],'FAIL')
            self.assertNotIn('private',target.read_text())

    def test_receipt_aggregate_requires_parts_and_retains_original_contract(self):
        for complete in (True, False):
            with tempfile.TemporaryDirectory() as name:
                root=Path(name); parts=root/'parts'; parts.mkdir(); needs,rows=fixture()
                for row in (rows if complete else rows[:-1]): (parts/(row['profile']+'.json')).write_text(json.dumps(row))
                with patch.object(receipts,'ROOT',root), patch.object(receipts,'output',return_value=SOURCE), \
                     patch.object(receipts.subprocess,'run',return_value=SimpleNamespace(returncode=0)) as run, \
                     patch('sys.argv',['receipt','backend','--parts',str(parts)]), \
                     patch.dict(os.environ,GITHUB_SHA=SOURCE,BACKEND_NEEDS=json.dumps(needs)):
                    with self.assertRaises(SystemExit if complete else ValueError) as result: receipts.main()
                receipt=json.loads((root/'.out/checks/backend.json').read_text())
                self.assertEqual(receipt,{'source_revision':SOURCE,'gate':'backend','status':'PASS' if complete else 'FAIL'})
                self.assertEqual(run.call_count,1)

    def test_actual_go_event_verifier_rejects_skips_failures_and_empty_runs(self):
        import subprocess
        import sys
        verifier=Path(__file__).resolve().parents[3]/'tools/verify/go_test_events/verify-go-test-events.py'
        with tempfile.TemporaryDirectory() as name:
            path=Path(name)/'events.jsonl'
            for action in ('pass','skip','fail',None):
                rows=[] if action is None else [{'Action':action,'Package':'synthetic','Test':'TestExample'}]
                path.write_text(''.join(json.dumps(row)+'\n' for row in rows))
                result=subprocess.run([sys.executable,str(verifier),str(path)],capture_output=True)
                self.assertEqual(result.returncode,0 if action == 'pass' else 1)
