"""Download validation fails before credentials on mutated metadata or payload."""
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
from . import authority
from .test_preflight import reader
from .test_producer_artifacts import SHA, REPO


class DownloadSnapshotTests(unittest.TestCase):
    def setUp(self):
        self.env = {'GITHUB_REPOSITORY': REPO, 'BUILD_RUN_ID': '123', 'GITHUB_TOKEN': 'private-canary'}

    def test_snapshot_is_complete_private_and_revalidated_before_payload(self):
        with tempfile.TemporaryDirectory() as tmp, patch.dict(os.environ, self.env, clear=True):
            snapshot = Path(tmp).resolve()/'authority.json'; output = Path(tmp).resolve()/'output'
            with patch.object(authority, 'Reader', return_value=reader()): authority.prepare(snapshot, output)
            self.assertEqual(0o600, snapshot.stat().st_mode & 0o777)
            values = dict(line.split('=', 1) for line in output.read_text().splitlines())
            self.assertEqual('44', values['artifact_id'])
            with patch.object(authority, 'Reader', return_value=reader()), patch.object(authority, 'inspect') as inspect:
                authority.recheck(snapshot, Path(tmp).resolve())
                inspect.assert_called_once_with(Path(tmp).resolve(), SHA)
            self.assertNotIn('private-canary', snapshot.read_text())

    def test_changed_producer_cannot_reach_payload_or_key_configuration(self):
        with tempfile.TemporaryDirectory() as tmp, patch.dict(os.environ, self.env, clear=True):
            snapshot = Path(tmp).resolve()/'authority.json'
            with patch.object(authority, 'Reader', return_value=reader()): authority.prepare(snapshot, Path(tmp).resolve()/'output')
            value = json.loads(snapshot.read_text()); value['id'] = 999; snapshot.write_text(json.dumps(value))
            with patch.object(authority, 'Reader', return_value=reader()), patch.object(authority, 'inspect') as inspect:
                with self.assertRaises(ValueError): authority.recheck(snapshot, Path(tmp).resolve())
                inspect.assert_not_called()

    def test_existing_linked_or_oversized_snapshot_is_not_accepted(self):
        with tempfile.TemporaryDirectory() as tmp, patch.dict(os.environ, self.env, clear=True):
            root = Path(tmp).resolve(); snapshot = root/'authority.json'; snapshot.write_text('{}')
            with self.assertRaises(FileExistsError): authority.prepare(snapshot, root/'output')
            snapshot.write_text(' ' * 8193)
            with self.assertRaises(ValueError): authority.recheck(snapshot, root)
            linked = root/'linked'; linked.symlink_to(snapshot)
            with self.assertRaises(ValueError): authority.recheck(linked, root)

    def test_failed_producer_creates_no_download_outputs(self):
        with tempfile.TemporaryDirectory() as tmp, patch.dict(os.environ, self.env, clear=True):
            root = Path(tmp).resolve(); broken = reader(); broken.read.return_value = None; broken.read.side_effect = ValueError('unavailable')
            with patch.object(authority, 'Reader', return_value=broken), self.assertRaises(ValueError):
                authority.prepare(root/'authority.json', root/'output')
            self.assertFalse((root/'authority.json').exists()); self.assertFalse((root/'output').exists())
