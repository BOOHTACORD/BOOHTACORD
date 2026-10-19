"""Corrupt, linked or ambiguous ownership journals cannot authorize deletion."""
import json
from pathlib import Path
import tempfile
import unittest
from .storage_lease import Lease

ROW = dict(owner='a'*32, image='moby/buildkit@sha256:'+'b'*64,
           revision='c'*40, archive='d'*64, daemon_sha256='e'*64)


class StorageLeaseTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()

    def test_duplicate_json_keys_are_rejected(self):
        with Lease(self.root/'lease') as lease:
            path=lease.root/'active.json'
            path.write_text('{"owner":"'+'f'*32+'",'+json.dumps(ROW)[1:])
            path.chmod(0o600)
            with self.assertRaises(ValueError):lease.read()

    def test_newly_linked_staging_file_is_preserved(self):
        foreign=self.root/'foreign';foreign.write_text('preserve')
        with Lease(self.root/'lease') as lease:
            temporary=lease.root/'active.tmp';temporary.symlink_to(foreign)
            with self.assertRaises(ValueError):lease.save(ROW)
            self.assertTrue(temporary.is_symlink())
        self.assertEqual('preserve',foreign.read_text())

    def test_journal_read_rechecks_permissions_after_lock(self):
        with Lease(self.root/'lease') as lease:
            lease.save(ROW)
            (lease.root/'active.json').chmod(0o644)
            with self.assertRaises(ValueError):lease.read()

    def test_corrupt_journal_cannot_be_cleared(self):
        with Lease(self.root/'lease') as lease:
            path=lease.root/'active.json';path.write_text('truncated');path.chmod(0o600)
            with self.assertRaises(ValueError):lease.clear()
            self.assertEqual('truncated',path.read_text())

    def test_symbolic_root_and_boolean_marker_are_rejected(self):
        real=self.root/'real';real.mkdir(mode=0o700)
        linked=self.root/'linked';linked.symlink_to(real,target_is_directory=True)
        with self.assertRaises(ValueError):
            with Lease(linked):self.fail('Indirect root accepted')
        with Lease(self.root/'lease'):pass
        marker=self.root/'lease/.owner.json'
        value=json.loads(marker.read_text());value['version']=True;marker.write_text(json.dumps(value))
        with self.assertRaises(ValueError):
            with Lease(self.root/'lease'):self.fail('Boolean schema accepted')
