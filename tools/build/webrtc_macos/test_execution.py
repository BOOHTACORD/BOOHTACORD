import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
from . import execution

IDENTITY=dict(builder_revision='a'*40,run_id='101',run_attempt='1')


class WorkspaceTests(unittest.TestCase):
    def test_cleanup_only_exact_owned_fresh_workspace(self):
        with tempfile.TemporaryDirectory() as directory,patch.object(execution,'ROOT',Path(directory).resolve()),patch.object(execution,'context',return_value=IDENTITY):
            root=Path(directory).resolve();workspace=root/'.out/webrtc/sdk'
            execution.own(workspace,'arm64')
            with self.assertRaises(ValueError):execution.own(workspace,'arm64')
            marker=root/'.out/webrtc/owner.json';marker.write_text(json.dumps(dict(IDENTITY,architecture='x64')))
            with self.assertRaises(ValueError):execution.cleanup('arm64')
            self.assertTrue(workspace.exists())
            marker.write_text(json.dumps(dict(IDENTITY,architecture='arm64')));execution.cleanup('arm64');self.assertFalse(workspace.exists())

    def test_personal_host_does_not_qualify_as_publishable_sdk(self):
        with patch.dict('os.environ',{},clear=True),self.assertRaises(ValueError):execution.context()
