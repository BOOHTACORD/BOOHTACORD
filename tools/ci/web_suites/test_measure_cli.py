"""CLI evidence is fail-closed and read-only metadata errors cannot expose tokens."""
import contextlib
import io
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
from urllib.error import HTTPError
from . import measure
from .test_comparison import fixture,SOURCE


class MeasureCLITests(unittest.TestCase):
    def test_complete_actual_metadata_is_required_before_writing_pass(self):
        run,jobs,needs,old,new=fixture()
        with tempfile.TemporaryDirectory() as name:
            root=Path(name)
            with patch.object(measure,'ROOT',root), patch.object(measure,'checked_source',return_value=(SOURCE,False)) as source_check, \
                 patch.object(measure.catalog,'execution',return_value={'run_id':'123','run_attempt':'1','namespace':'shadow-compare'}), \
                 patch.object(measure,'read_inputs',return_value=(old,new)), \
                 patch.object(measure,'read_api',side_effect=[run,jobs]) as read, \
                 patch.dict(os.environ,SHADOW_NEEDS=json.dumps(needs)), contextlib.redirect_stdout(io.StringIO()):
                measure.main()
            result=json.loads((root/'.out/ci/web-shadow.json').read_text())
            self.assertEqual(result['status'],'PASS');self.assertEqual(read.call_count,2)
            source_check.assert_called_once_with(verify_node=False)

    def test_missing_control_replaces_stale_pass_and_fails(self):
        run,jobs,needs,old,new=fixture();old.pop()
        with tempfile.TemporaryDirectory() as name:
            root=Path(name);path=root/'.out/ci/web-shadow.json';path.parent.mkdir(parents=True);path.write_text('{"status":"PASS"}')
            with patch.object(measure,'ROOT',root), patch.object(measure,'checked_source',return_value=(SOURCE,False)), \
                 patch.object(measure.catalog,'execution',return_value={'run_id':'123','run_attempt':'1','namespace':'shadow-compare'}), \
                 patch.object(measure,'read_inputs',return_value=(old,new)), patch.object(measure,'read_api',side_effect=[run,jobs]), \
                 patch.dict(os.environ,SHADOW_NEEDS=json.dumps(needs)),self.assertRaises(ValueError): measure.main()
            self.assertEqual(json.loads(path.read_text())['status'],'FAIL')

    def test_api_error_does_not_print_token_or_error_body(self):
        failure=HTTPError('https://api.github.com/',403,'PRIVATE-CANARY',{},None)
        with patch.dict(os.environ,GITHUB_TOKEN='TOKEN-CANARY'), \
             patch.object(measure,'urlopen',side_effect=failure),self.assertRaises(RuntimeError) as caught:
            measure.read_api('/actions/runs/123')
        self.assertNotIn('TOKEN-CANARY',str(caught.exception))
        self.assertNotIn('PRIVATE-CANARY',str(caught.exception))
