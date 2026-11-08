"""The native acceptance fixture must authenticate tools before extraction."""
import hashlib
import io
from pathlib import Path
import tempfile
import unittest
import urllib.error
from unittest.mock import patch
import zipfile

from .windows_tools import download_verified, extract_verified


class WindowsToolTests(unittest.TestCase):
    def test_timed_out_download_retries_without_reusing_partial_bytes(self):
        class Interrupted(io.BytesIO):
            def read(self, size=-1):
                if self.tell(): raise TimeoutError('fixture timeout')
                return super().read(2)

        with tempfile.TemporaryDirectory() as folder:
            archive = Path(folder) / 'tool.zip'
            data = b'fixture'
            with patch('urllib.request.urlopen', side_effect=[Interrupted(data), io.BytesIO(data)]) as fetch, \
                 patch('time.sleep'):
                download_verified('https://example.test/tool.zip', archive, len(data), hashlib.sha256(data).hexdigest())
            self.assertEqual(fetch.call_count, 2)
            self.assertEqual(archive.read_bytes(), data)

    def test_untrusted_digest_is_rejected_without_retry_or_retained_archive(self):
        with tempfile.TemporaryDirectory() as folder:
            archive = Path(folder) / 'tool.zip'
            with patch('urllib.request.urlopen', return_value=io.BytesIO(b'fixture')) as fetch, \
                 self.assertRaises(ValueError):
                download_verified('https://example.test/tool.zip', archive, 7, '0' * 64)
            self.assertEqual(fetch.call_count, 1)
            self.assertFalse(archive.exists())

    def test_retries_are_bounded_and_remove_partial_archive(self):
        with tempfile.TemporaryDirectory() as folder:
            archive = Path(folder) / 'tool.zip'
            with patch('urllib.request.urlopen', side_effect=TimeoutError('fixture timeout')) as fetch, \
                 patch('time.sleep') as delay, self.assertRaises(TimeoutError):
                download_verified('https://example.test/tool.zip', archive, 7, '0' * 64)
            self.assertEqual(fetch.call_count, 3)
            self.assertEqual(delay.call_count, 2)
            self.assertFalse(archive.exists())

    def test_existing_archive_is_never_overwritten(self):
        with tempfile.TemporaryDirectory() as folder:
            archive = Path(folder) / 'tool.zip'
            archive.write_bytes(b'original')
            with patch('urllib.request.urlopen') as fetch, self.assertRaises(FileExistsError):
                download_verified('https://example.test/tool.zip', archive, 7, '0' * 64)
            fetch.assert_not_called()
            self.assertEqual(archive.read_bytes(), b'original')

    def test_transient_http_errors_retry_but_not_missing_files(self):
        with tempfile.TemporaryDirectory() as folder:
            archive = Path(folder) / 'tool.zip'
            data = b'fixture'
            unavailable = urllib.error.HTTPError('https://example.test', 503, 'unavailable', {}, None)
            with patch('urllib.request.urlopen', side_effect=[unavailable, io.BytesIO(data)]) as fetch, \
                 patch('time.sleep'):
                download_verified('https://example.test/tool.zip', archive, len(data), hashlib.sha256(data).hexdigest())
            self.assertEqual(fetch.call_count, 2)
            self.assertEqual(archive.read_bytes(), data)
        with tempfile.TemporaryDirectory() as folder:
            archive = Path(folder) / 'tool.zip'
            missing = urllib.error.HTTPError('https://example.test', 404, 'missing', {}, None)
            with patch('urllib.request.urlopen', side_effect=missing) as fetch, self.assertRaises(urllib.error.HTTPError):
                download_verified('https://example.test/tool.zip', archive, 7, '0' * 64)
            self.assertEqual(fetch.call_count, 1)
            self.assertFalse(archive.exists())

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
