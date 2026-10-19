import json
import unittest
from .summary import observe,markdown


class SummaryTests(unittest.TestCase):
    def test_failed_or_missing_artifact_is_red_with_source_step_and_reproduction(self):
        run=dict(id=101,run_attempt=1,head_sha='a'*40,event='push',path='.github/workflows/build-server.yaml',repository={'full_name':'Egkurilov/BOOHTACORD'})
        env=dict(GITHUB_RUN_ID='101',GITHUB_RUN_ATTEMPT='1',CI_GATE_OUTCOME='failure')
        jobs=[dict(id=12,name='backend / tests',conclusion='failure',steps=[dict(number=3,name='Retain sensitive-value-must-not-appear',conclusion='failure')])]
        row=observe('server',env,run,jobs,'a'*40,[],{})
        self.assertEqual('FAIL',row['outcome']);self.assertEqual(3,row['failures'][0]['step_number'])
        self.assertIn('/job/12',markdown(row));self.assertIn('tools.ci.native.backend',markdown(row))
        self.assertNotIn('sensitive-value-must-not-appear',json.dumps(row))
        row=observe('server',env,run,[],'a'*40,[],{});self.assertEqual('FAIL',row['outcome'])

    def test_wrong_source_never_produces_summary_pass(self):
        run=dict(id=101,run_attempt=1,head_sha='b'*40,event='push',repository={'full_name':'Egkurilov/BOOHTACORD'})
        with self.assertRaises(ValueError):observe('server',dict(GITHUB_RUN_ID='101',GITHUB_RUN_ATTEMPT='1'),run,[],'a'*40,[],{})

    def test_cancelled_dependency_remains_red_without_claiming_a_master_defect(self):
        run=dict(id=101,run_attempt=1,head_sha='a'*40,event='pull_request',path='.github/workflows/ci.yaml',repository={'full_name':'Egkurilov/BOOHTACORD'})
        env=dict(GITHUB_RUN_ID='101',GITHUB_RUN_ATTEMPT='1',CI_GATE_OUTCOME='failure')
        row=observe('pr',env,run,[],'a'*40,[],{'backend':{'result':'cancelled'}})
        self.assertEqual('CANCELLED',row['outcome']);self.assertFalse(row['master_defect'])

    def test_unavailable_metadata_writes_blocked_receipt_and_never_leaks_error_text(self):
        import contextlib,io,tempfile
        from pathlib import Path
        from unittest.mock import patch
        from . import summary
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory).resolve();stream=io.StringIO()
            env=dict(GITHUB_RUN_ID='101',GITHUB_RUN_ATTEMPT='1',GITHUB_SHA='a'*40,GITHUB_TOKEN='do-not-log',GITHUB_STEP_SUMMARY=str(root/'summary.md'))
            with patch.object(summary,'ROOT',root),patch.dict('os.environ',env,clear=True), \
                 patch('sys.argv',['summary','--scope','pr']),patch.object(summary.subprocess,'check_output',side_effect=['a'*40,'']), \
                 patch.object(summary,'metadata',side_effect=RuntimeError('do-not-log')),contextlib.redirect_stdout(stream):
                self.assertEqual(1,summary.main())
            raw=(root/'.out/ci/triage/pr.json').read_text()+(root/'summary.md').read_text()+stream.getvalue()
            self.assertNotIn('do-not-log',raw);self.assertEqual('BLOCKED',json.loads((root/'.out/ci/triage/pr.json').read_text())['outcome'])
