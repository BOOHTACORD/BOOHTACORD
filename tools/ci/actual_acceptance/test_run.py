"""Controller failure, interruption and cleanup failure all retain a red receipt."""
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
from . import run


class RuntimeFinalizerTests(unittest.TestCase):
    def test_always_cleanup_owned_namespace_and_never_pass_a_cleanup_failure(self):
        for failure in (None,KeyboardInterrupt(),ValueError('controller failed'),'cleanup'):
            with tempfile.TemporaryDirectory() as temporary,self.subTest(failure=type(failure).__name__):
                root=Path(temporary);row=dict(owner='qa-client-'+'a'*16)
                with patch.object(run,'ROOT',root),patch.object(run.session,'hosted'), \
                     patch.object(run,'output',return_value='b'*40),patch.object(run.subprocess,'run'), \
                     patch.object(run.session,'identity',return_value=row),patch.object(run.session,'child_environment',return_value={}), \
                     patch.dict('os.environ',{'GITHUB_SHA':'b'*40}),patch.dict(run.catalog.OPERATIONS,{'sfu':[]}), \
                     patch.object(run,'collect',side_effect=failure if isinstance(failure,BaseException) else None,return_value={}), \
                     patch.object(run.session,'cleanup',side_effect=RuntimeError() if failure=='cleanup' else None,return_value=True) as cleanup:
                    if failure is None:run.execute('sfu','c'*40)
                    else:
                        with self.assertRaises(SystemExit):run.execute('sfu','c'*40)
                    cleanup.assert_called_once_with(row['owner'])
                report=json.loads((root/'.out/actual-acceptance/public/sfu/result.json').read_text())
                self.assertEqual('PASS' if failure is None else 'FAIL',report['status'])
