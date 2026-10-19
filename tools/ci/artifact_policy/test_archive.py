"""Downloaded ZIP bytes must match API checksums before safe package inspection."""
import hashlib
import tempfile
import unittest
import zipfile
from pathlib import Path
from . import archive, captures
from .test_captures import identity
from . import test_captures as fixtures


class CaptureArchiveTests(unittest.TestCase):
    def fixture(self, root):
        package = root / 'package'
        captures.pack(fixtures.CapturePackageTests().fixture(root), package, identity())
        path = root / 'download.zip'
        with zipfile.ZipFile(path, 'w', zipfile.ZIP_DEFLATED) as stream:
            for item in sorted(package.rglob('*')):
                if item.is_file(): stream.write(item, item.relative_to(package).as_posix())
        return path, hashlib.sha256(path.read_bytes()).hexdigest(), path.stat().st_size

    def test_actual_download_bytes_unpack_and_restore_original_logical_files(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp).resolve(); path, digest, size = self.fixture(root)
            manifest = archive.unpack(path, root / 'downloaded', identity(), digest, size)
            self.assertEqual(3, len(manifest['files']))
            captures.restore(root / 'downloaded', root / 'restored', identity())
            self.assertEqual(3, sum(p.is_file() for p in (root / 'restored').rglob('*')))

    def test_checksum_size_or_foreign_identity_cannot_leave_a_partial_public_directory(self):
        for change in ('digest', 'size', 'identity'):
            with self.subTest(change=change), tempfile.TemporaryDirectory() as tmp:
                root = Path(tmp).resolve(); path, digest, size = self.fixture(root); expected = identity()
                if change == 'digest': digest = '0' * 64
                if change == 'size': size += 1
                if change == 'identity': expected['run_attempt'] = '2'
                with self.assertRaises(ValueError): archive.unpack(path, root / 'downloaded', expected, digest, size)
                self.assertFalse((root / 'downloaded').exists())

    def test_unsafe_duplicate_or_unexpected_members_are_rejected_before_extraction(self):
        import warnings
        for name in ('../outside.png', '/absolute.png', 'payload/../outside.png',
                     'payload\\outside.png', 'client.log', 'payload/foreign.png', 'artifact-manifest.json'):
            with self.subTest(kind='unsafe-zip'), tempfile.TemporaryDirectory() as tmp:
                root = Path(tmp).resolve(); path, _, _ = self.fixture(root)
                with warnings.catch_warnings():
                    warnings.simplefilter('ignore', UserWarning)
                    with zipfile.ZipFile(path, 'a') as stream: stream.writestr(name, b'private-canary')
                digest = hashlib.sha256(path.read_bytes()).hexdigest()
                with self.assertRaises(ValueError) as error:
                    archive.unpack(path, root / 'downloaded', identity(), digest, path.stat().st_size)
                self.assertNotIn('private-canary', str(error.exception))
                self.assertFalse((root / 'downloaded').exists())

    def test_linked_zip_parent_or_occupied_destination_is_not_modified(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp).resolve(); path, digest, size = self.fixture(root)
            existing = root / 'occupied'; existing.mkdir(); (existing / 'keep').write_text('unchanged')
            with self.assertRaises(ValueError): archive.unpack(path, existing, identity(), digest, size)
            self.assertEqual('unchanged', (existing / 'keep').read_text())
            linked = root / 'linked'; linked.symlink_to(root, target_is_directory=True)
            with self.assertRaises(ValueError): archive.unpack(linked / path.name, root / 'downloaded', identity(), digest, size)

    def test_zip_links_and_declared_expansion_budget_are_rejected(self):
        from unittest.mock import patch
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp).resolve(); path, digest, size = self.fixture(root)
            with patch.object(archive, 'MAX_ARCHIVE', size - 1), self.assertRaises(ValueError):
                archive.unpack(path, root / 'downloaded', identity(), digest, size)
            with zipfile.ZipFile(path, 'a') as stream:
                item = zipfile.ZipInfo('payload/' + 'a' * 64 + '.png'); item.create_system = 3
                item.external_attr = (0o120777 << 16); stream.writestr(item, b'outside')
            digest = hashlib.sha256(path.read_bytes()).hexdigest()
            with self.assertRaises(ValueError): archive.unpack(path, root / 'downloaded', identity(), digest, path.stat().st_size)
