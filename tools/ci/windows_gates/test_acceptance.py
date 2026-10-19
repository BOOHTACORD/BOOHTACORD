"""Failures in either actual-process boundary never leave a passing receipt."""
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
from . import acceptance
from .test_transfer import SOURCE
from tools.qa.screen_setup.test_windows import fixture


class AcceptanceTests(unittest.TestCase):
    def test_recovery_gui_or_post_run_payload_failure_cannot_pass(self):
        for failure in ('recovery','gui','payload',None):
            with tempfile.TemporaryDirectory() as name:
                root=Path(name)
                binding={'source_revision':SOURCE,'execution':{'run_id':'local','run_attempt':'1'},
                         'release':{'artifact-manifest.json':{'sha256':'b'*64}}}
                recovery={'status':'PASS'}
                gui=fixture();gui['manifest_sha256']='b'*64
                with patch.object(acceptance,'ROOT',root),patch.object(acceptance,'load',return_value={'native_build':'1'}), \
                     patch.object(acceptance,'verify_workspace',side_effect=[binding,ValueError('changed')] if failure=='payload' else [binding,binding]), \
                     patch.object(acceptance,'recovery',side_effect=RuntimeError('failed') if failure=='recovery' else None), \
                     patch.object(acceptance,'gui',side_effect=RuntimeError('failed') if failure=='gui' else None), \
                     patch.object(acceptance,'read',side_effect=[recovery,gui]):
                    if failure:
                        with self.assertRaises((RuntimeError,ValueError)):acceptance.main()
                    else:acceptance.main()
                self.assertEqual(json.loads((root/'.out/ci/windows-acceptance.json').read_text())['status'],
                                 'FAIL' if failure else 'PASS')
