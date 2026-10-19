"""Verify the actual retained ZIP, then atomically publish only its transport pair."""
import hashlib
from pathlib import Path
import re
import stat
import tempfile
import zipfile
from .payload import inspect, MAX_BUNDLE

MAX_ARCHIVE = 8_100_000_000


def unpack(archive, destination, revision, digest, size):
    try:
        archive, destination = Path(archive), Path(destination)
        if (not archive.is_absolute() or archive.resolve() != archive or not archive.is_file()
                or archive.stat().st_nlink != 1 or not destination.is_absolute()
                or destination.parent.resolve() != destination.parent or destination.exists() or destination.is_symlink()
                or not isinstance(revision, str) or not re.fullmatch('[a-f0-9]{40}', revision)
                or type(size) is not int or not 0 < size <= MAX_ARCHIVE or archive.stat().st_size != size): raise ValueError
        if digest is not None:
            if not isinstance(digest, str) or not re.fullmatch('sha256:[a-f0-9]{64}', digest): raise ValueError
            with archive.open('rb') as stream:
                if hashlib.file_digest(stream, 'sha256').hexdigest() != digest.removeprefix('sha256:'): raise ValueError
        name = revision + '.release.tar.gz'
        expected = {name: MAX_BUNDLE, name + '.sha256': 256}
        with zipfile.ZipFile(archive) as stream, tempfile.TemporaryDirectory(prefix='.artifact-unpack-', dir=destination.parent) as temp:
            rows = stream.infolist()
            if len(rows) != 2 or {row.filename for row in rows} != set(expected): raise ValueError
            incoming = Path(temp)/'incoming'; incoming.mkdir()
            for row in rows:
                if (row.is_dir() or row.flag_bits & 1 or row.compress_type not in (zipfile.ZIP_STORED, zipfile.ZIP_DEFLATED)
                        or stat.S_IFMT(row.external_attr >> 16) not in (0, stat.S_IFREG)
                        or not 0 < row.file_size <= expected[row.filename]): raise ValueError
                with stream.open(row) as source, (incoming/row.filename).open('xb') as target:
                    count = 0
                    while block := source.read(1024 * 1024):
                        count += len(block)
                        if count > row.file_size: raise ValueError
                        target.write(block)
                    if count != row.file_size: raise ValueError
            payload = inspect(incoming, revision)
            incoming.rename(destination)
        return {'outer_digest': 'verified' if digest else 'unavailable-legacy',
                'archive_bytes': size, 'bundle_sha256': payload['sha256'], 'bundle_bytes': payload['bytes']}
    except (OSError, ValueError, TypeError, zipfile.BadZipFile, RuntimeError):
        raise ValueError('Downloaded release artifact differs or is unsafe') from None
