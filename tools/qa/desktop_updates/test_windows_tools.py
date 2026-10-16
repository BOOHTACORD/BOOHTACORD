"""The native acceptance fixture must authenticate tools before extraction."""
import hashlib
from pathlib import Path
import tempfile
import unittest
import zipfile

from .windows_tools import extract_verified


class WindowsToolTests(unittest.TestCase):
    def archive(self, root, name='pgsql/bin/postgres.exe', symlink=False):
        archive = root / 'tool.zip'
        with zipfile.ZipFile(archive, 'w') as output:
            item = zipfile.ZipInfo(name)
            if symlink:
                item.create_system = 3
                item.external_attr = 0o120777 << 16
            output.writestr(item, b'fixture')
        return archive, hashlib.sha256(archive.read_bytes()).hexdigest()

    def test_bad_digest_never_creates_destination(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            archive, _ = self.archive(root)
            with self.assertRaises(ValueError):
                extract_verified(archive, root / 'out', '0' * 64)
            self.assertFalse((root / 'out').exists())

    def test_windows_path_and_symlink_escapes_are_rejected(self):
        for name in ('../escape', '/absolute', r'C:\escape', 'file:stream',
                     r'pgsql\..\escape', r'\\server\share\escape'):
            with self.subTest(name=name), tempfile.TemporaryDirectory() as folder:
                root = Path(folder)
                archive, digest = self.archive(root, name)
                with self.assertRaises(ValueError):
                    extract_verified(archive, root / 'out', digest)
                self.assertFalse((root / 'out').exists())
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            archive, digest = self.archive(root, symlink=True)
            with self.assertRaises(ValueError):
                extract_verified(archive, root / 'out', digest)

    def test_verified_regular_archive_is_extracted_without_overwrite(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            archive, digest = self.archive(root)
            extract_verified(archive, root / 'out', digest)
            self.assertEqual((root / 'out/pgsql/bin/postgres.exe').read_bytes(), b'fixture')
            with self.assertRaises(FileExistsError):
                extract_verified(archive, root / 'out', digest)
