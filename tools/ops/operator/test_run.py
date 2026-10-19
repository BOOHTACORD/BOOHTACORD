import contextlib
import io
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
from tools.release.delivery.commands import ExecutionFailed
from . import run
from .test_policy import context


class OperatorRunTests(unittest.TestCase):
    def test_dry_run_and_missing_approval_never_connect_or_expose_credentials(self):
        for dry in ('true','false'):
            with tempfile.TemporaryDirectory() as directory,self.subTest(dry=dry):
                env=context(OPERATOR_DRY_RUN=dry,OPERATOR_CONFIRM='read-only-observation',GITHUB_ACTIONS='true',
                            RUNNER_ENVIRONMENT='github-hosted',OPERATOR_SSH_PRIVATE_KEY='private-value-never-log')
                stream=io.StringIO()
                with patch.object(run,'ROOT',Path(directory)),patch.object(run,'output',return_value='a'*40), \
                     patch.dict('os.environ',env,clear=True),patch.object(run.approval,'verify',side_effect=ValueError('private-value-never-log')), \
                     patch.object(run,'SSH') as ssh,contextlib.redirect_stdout(stream):
                    if dry=='true':run.execute('audit')
                    else:
                        with self.assertRaises(SystemExit):run.execute('audit')
                    ssh.assert_not_called()
                raw=(Path(directory)/'.out/operator/audit/receipt.json').read_text()
                self.assertNotIn('private-value-never-log',raw+stream.getvalue())
                self.assertEqual('NOT_RUN' if dry=='true' else 'BLOCKED',json.loads(raw)['status'])

    def test_unavailable_host_is_red_and_private_identity_is_removed(self):
        with tempfile.TemporaryDirectory() as directory:
            env=context(OPERATOR_DRY_RUN='false',OPERATOR_CONFIRM='read-only-observation',GITHUB_ACTIONS='true',
                        RUNNER_ENVIRONMENT='github-hosted',RUNNER_TEMP=directory)
            with patch.object(run,'ROOT',Path(directory)),patch.object(run,'output',return_value='a'*40), \
                 patch.dict('os.environ',env,clear=True),patch.object(run.approval,'verify',return_value=[43]), \
                 patch.object(run,'SSH'),patch.object(run,'perform',side_effect=ExecutionFailed('timeout')):
                with self.assertRaises(SystemExit):run.execute('audit')
            report=json.loads((Path(directory)/'.out/operator/audit/receipt.json').read_text())
            self.assertEqual('FAIL',report['status']);self.assertTrue(report['private_runner_material_removed'])
            self.assertFalse(list(Path(directory).glob('operator-*')))
