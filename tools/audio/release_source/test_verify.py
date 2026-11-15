from pathlib import Path
import hashlib
import io
import tarfile
import unittest
import tempfile
from unittest.mock import patch

from tools.audio.release_source.verify import unpack


def fixture(tmp_path, *, unsafe=False):
    archive = tmp_path / 'source.tar.gz'
    body = b'licensed model fixture'
    with tarfile.open(archive, 'w:gz') as tar:
        item = tarfile.TarInfo('../escape' if unsafe else 'engine/COPYING')
        item.size = len(body)
        tar.addfile(item, io.BytesIO(body))
    lock = {'archiveSha256': hashlib.sha256(archive.read_bytes()).hexdigest(),
            'root': 'engine', 'files': {'COPYING': hashlib.sha256(body).hexdigest()}}
    return archive, lock



class SourceDistributionTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)

    def test_verifies_archive_and_notice_before_extracting(self):
        tmp_path = self.root
        archive, lock = fixture(tmp_path)
        root = unpack(archive, tmp_path / 'checked', lock)
        assert (root / 'COPYING').read_bytes() == b'licensed model fixture'


    def test_corrupt_archive_never_creates_output(self):
        tmp_path = self.root
        archive, lock = fixture(tmp_path)
        archive.write_bytes(archive.read_bytes() + b'changed')
        output = tmp_path / 'checked'
        with self.assertRaisesRegex(ValueError, 'archive checksum'):
            unpack(archive, output, lock)
        assert not output.exists()


    def test_model_or_notice_mismatch_never_creates_output(self):
        tmp_path = self.root
        archive, lock = fixture(tmp_path)
        lock['files']['COPYING'] = '0' * 64
        output = tmp_path / 'checked'
        with self.assertRaisesRegex(ValueError, 'file checksum'):
            unpack(archive, output, lock)
        assert not output.exists()


    def test_rejects_traversal_and_existing_destination(self):
        tmp_path = self.root
        archive, lock = fixture(tmp_path, unsafe=True)
        with self.assertRaisesRegex(ValueError, 'unsafe archive'):
            unpack(archive, tmp_path / 'checked', lock)
        assert not (tmp_path / 'escape').exists()
        archive, lock = fixture(tmp_path)
        output = tmp_path / 'existing'
        output.mkdir()
        (output / 'preserved').write_text('owner data')
        with self.assertRaisesRegex(ValueError, 'already exists'):
            unpack(archive, output, lock)
        assert (output / 'preserved').read_text() == 'owner data'


    def test_cached_tree_rejects_changed_or_injected_source(self):
        tmp_path = self.root
        from tools.audio.release_source import verify
        archive, lock = fixture(tmp_path)
        loader = patch.object(verify, 'load', return_value=lock)
        loader.start()
        self.addCleanup(loader.stop)
        output = tmp_path / 'checked'
        root = verify.prepare(output, archive=archive)
        assert verify.prepare(output, archive=archive) == root
        (root / 'injected.h').write_text('different code')
        with self.assertRaisesRegex(ValueError, 'cached source checksum'):
            verify.prepare(output, archive=archive)
