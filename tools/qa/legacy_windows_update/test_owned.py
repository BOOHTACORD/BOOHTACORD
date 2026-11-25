"""A locked Windows fixture root cannot leave a premature successful receipt."""
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch
from . import owned


class OwnedLifetimeTests(unittest.TestCase):
    def test_receipt_is_written_only_after_owned_root_is_removed(self):
        with tempfile.TemporaryDirectory() as directory:
            parent=Path(directory);report={'status':'FAIL'};file=parent/'result.json'
            with owned.scope(parent,report,file) as root:
                self.assertTrue(root.is_dir());self.assertFalse(file.exists())
                report['status']='PASS'
            self.assertFalse(root.exists())
            self.assertEqual(json.loads(file.read_text())['status'],'PASS')
            self.assertTrue(report['resources_removed'])

    def test_cleanup_failure_replaces_premature_pass_with_fail(self):
        with tempfile.TemporaryDirectory() as directory:
            parent=Path(directory);file=parent/'result.json';report={'status':'FAIL'}
            with patch.object(owned,'remove_root',side_effect=PermissionError('locked')):
                with self.assertRaises(PermissionError):
                    with owned.scope(parent,report,file): report['status']='PASS'
            self.assertEqual(json.loads(file.read_text())['status'],'FAIL')
            self.assertFalse(report['resources_removed'])

    def test_invalid_owner_parent_or_root_is_never_deleted(self):
        with tempfile.TemporaryDirectory() as directory:
            parent=Path(directory);root,token=owned.create_root(parent)
            for candidate,base,nonce in [(root,parent,'0'*32),(root,parent/'other',token),
                                          (parent,parent,token)]:
                with patch.object(owned.shutil,'rmtree') as remove:
                    with self.assertRaises(ValueError):owned.remove_root(candidate,base,nonce)
                    remove.assert_not_called()

    def test_permanent_lock_is_bounded_and_does_not_claim_removal(self):
        with tempfile.TemporaryDirectory() as directory:
            parent=Path(directory);root,token=owned.create_root(parent)
            with patch.object(owned.shutil,'rmtree',side_effect=PermissionError('locked')), \
                 patch.object(owned.time,'monotonic',side_effect=[0,11]):
                with self.assertRaises(PermissionError):owned.remove_root(root,parent,token)
            self.assertTrue(root.exists())

    @unittest.skipUnless(sys.platform=='win32','Windows working-directory locks only')
    def test_real_windows_child_releases_root_before_success(self):
        with tempfile.TemporaryDirectory() as directory:
            parent=Path(directory);report={'status':'FAIL'};file=parent/'result.json'
            with owned.scope(parent,report,file) as root:
                child=subprocess.Popen([sys.executable,'-c',
                    'import os,sys,time;os.chdir(sys.argv[1]);print("ready",flush=True);time.sleep(.5)',str(root)],
                    stdout=subprocess.PIPE,stderr=subprocess.DEVNULL,creationflags=subprocess.CREATE_NO_WINDOW)
                self.assertEqual(child.stdout.readline().strip(),b'ready')
                report['status']='PASS'
            self.assertEqual(child.wait(timeout=5),0);child.stdout.close()
            self.assertFalse(root.exists());self.assertTrue(report['resources_removed'])
