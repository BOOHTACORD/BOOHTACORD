"""Corruption, manifest traversal and mutable/incomplete metadata fail closed."""
import hashlib
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
from . import packages


class PackageTests(unittest.TestCase):
    def test_checksums_reject_duplicate_unsafe_or_malformed_names(self):
        valid=('a'*64+'  artifact-manifest.json\r\n').encode()
        self.assertEqual(packages.checksums(valid),{'artifact-manifest.json':'a'*64})
        for data in [b'',valid+valid,b'x  file.exe',('a'*64+'  ../user.exe').encode()]:
            with self.subTest(data=data),self.assertRaises(ValueError):packages.checksums(data)

    def test_release_path_cannot_be_injected_before_network(self):
        with patch.object(packages,'read_public') as read:
            for version in ['../main','1.0.60?x','https://evil.test','1.0.60/anything']:
                with self.assertRaises(ValueError):packages.release_files(Path('unused'),version)
            read.assert_not_called()

    def test_actual_files_reject_corruption_size_and_traversal(self):
        with tempfile.TemporaryDirectory() as name:
            root=Path(name);(root/'app.exe').write_bytes(b'original')
            manifest={'files':{'app.exe':{'bytes':8,'sha256':hashlib.sha256(b'original').hexdigest()}}}
            packages.verify_files(root,manifest)
            (root/'app.exe').write_bytes(b'changed!')
            with self.assertRaises(ValueError):packages.verify_files(root,manifest)
            for path in ['../user','/user','C:/user','foo\\bar']:
                with self.subTest(path=path),self.assertRaises(ValueError):packages.verify_files(root,{'files':{path:{}}})

    def test_wrong_cache_headers_never_become_native_acceptance_input(self):
        for headers in [{},{'cache-control':'max-age=3600'},
                        {'cache-control':'no-store','x-content-type-options':'nosniff','content-type':'text/html'}]:
            with patch.object(packages,'read_public',return_value=(b'{}',headers)):
                with self.assertRaises(ValueError):packages.read_policy()
