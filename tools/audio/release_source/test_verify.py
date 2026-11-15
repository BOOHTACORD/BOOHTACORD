import hashlib
import io
import tarfile
import pytest

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


def test_verifies_archive_and_notice_before_extracting(tmp_path):
    archive, lock = fixture(tmp_path)
    root = unpack(archive, tmp_path / 'checked', lock)
    assert (root / 'COPYING').read_bytes() == b'licensed model fixture'


def test_corrupt_archive_never_creates_output(tmp_path):
    archive, lock = fixture(tmp_path)
    archive.write_bytes(archive.read_bytes() + b'changed')
    output = tmp_path / 'checked'
    with pytest.raises(ValueError, match='archive checksum'):
        unpack(archive, output, lock)
    assert not output.exists()


def test_model_or_notice_mismatch_never_creates_output(tmp_path):
    archive, lock = fixture(tmp_path)
    lock['files']['COPYING'] = '0' * 64
    output = tmp_path / 'checked'
    with pytest.raises(ValueError, match='file checksum'):
        unpack(archive, output, lock)
    assert not output.exists()


def test_rejects_traversal_and_existing_destination(tmp_path):
    archive, lock = fixture(tmp_path, unsafe=True)
    with pytest.raises(ValueError, match='unsafe archive'):
        unpack(archive, tmp_path / 'checked', lock)
    assert not (tmp_path / 'escape').exists()
    archive, lock = fixture(tmp_path)
    output = tmp_path / 'existing'
    output.mkdir()
    (output / 'preserved').write_text('owner data')
    with pytest.raises(ValueError, match='already exists'):
        unpack(archive, output, lock)
    assert (output / 'preserved').read_text() == 'owner data'


def test_cached_tree_rejects_changed_or_injected_source(tmp_path, monkeypatch):
    from tools.audio.release_source import verify
    archive, lock = fixture(tmp_path)
    monkeypatch.setattr(verify, 'load', lambda: lock)
    output = tmp_path / 'checked'
    root = verify.prepare(output, archive=archive)
    assert verify.prepare(output, archive=archive) == root
    (root / 'injected.h').write_text('different code')
    with pytest.raises(ValueError, match='cached source checksum'):
        verify.prepare(output, archive=archive)
