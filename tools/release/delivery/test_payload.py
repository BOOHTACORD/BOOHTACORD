"""Transport checksum checks are independent of canonical signature/install authority."""
import hashlib
import tempfile
import unittest
from pathlib import Path
from .payload import inspect

SOURCE = 'a' * 40


class DeliveryPayloadTests(unittest.TestCase):
    def fixture(self, root):
        path = root / (SOURCE + '.release.tar.gz')
        path.write_bytes(b'controlled-transport-fixture')
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        checksum = root / (path.name + '.sha256')
        checksum.write_text(digest + '  ' + path.name + '\n')
        return path, checksum, digest

    def test_exact_two_source_files_are_measured_without_an_install_verdict(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp).resolve();path, _, digest = self.fixture(root)
            self.assertEqual({'path': path, 'sha256': digest, 'bytes': path.stat().st_size}, inspect(root, SOURCE))

    def test_tampered_payload_and_foreign_source_fail(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp).resolve();path, _, _ = self.fixture(root)
            with self.assertRaises(ValueError): inspect(root, 'b'*40)
            path.write_bytes(b'changed')
            with self.assertRaises(ValueError): inspect(root, SOURCE)

    def test_checksum_must_be_one_canonical_line_for_the_actual_source_filename(self):
        for suffix in ['  foreign.tar.gz\n', '  ' + SOURCE + '.release.tar.gz\nextra\n', '\n']:
            with self.subTest(suffix=suffix), tempfile.TemporaryDirectory() as temp:
                root = Path(temp).resolve();_, checksum, digest = self.fixture(root)
                checksum.write_text(digest + suffix)
                with self.assertRaises(ValueError): inspect(root, SOURCE)

    def test_extra_file_or_linked_payload_is_rejected(self):
        for kind in ('extra', 'symlink', 'hardlink'):
            with self.subTest(kind=kind), tempfile.TemporaryDirectory() as temp:
                root = Path(temp).resolve();directory = root/'incoming';directory.mkdir()
                path, _, _ = self.fixture(directory)
                if kind == 'extra': (directory/'unexpected').touch()
                else:
                    saved = root/'saved';path.rename(saved)
                    if kind == 'symlink': path.symlink_to(saved)
                    else: path.hardlink_to(saved)
                with self.assertRaises(ValueError): inspect(directory, SOURCE)

    def test_linked_parent_and_empty_file_are_not_accepted(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp).resolve();directory=root/'incoming';directory.mkdir()
            path, _, _=self.fixture(directory)
            linked=root/'linked';linked.symlink_to(directory, target_is_directory=True)
            with self.assertRaises(ValueError): inspect(linked, SOURCE)
            path.write_bytes(b'')
            with self.assertRaises(ValueError): inspect(directory, SOURCE)
