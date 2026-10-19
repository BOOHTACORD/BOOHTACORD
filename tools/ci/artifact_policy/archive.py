"""Verify downloaded archive bytes and extract only the finite capture package."""
import hashlib
import re
import shutil
import stat
import zipfile
from pathlib import Path
from . import capture_data as data, captures

MAX_ARCHIVE = 64 * 1024 * 1024


def members(stream):
    rows = stream.infolist()
    data.require(0 < len(rows) <= data.MAX_FILES + 2)
    seen, total = set(), 0
    for row in rows:
        name = row.filename
        data.require(name not in seen and not row.flag_bits & 1
                     and row.compress_type in (zipfile.ZIP_STORED, zipfile.ZIP_DEFLATED))
        seen.add(name)
        kind = stat.S_IFMT(row.external_attr >> 16)
        data.require(kind in (0, stat.S_IFREG, stat.S_IFDIR))
        if row.is_dir():
            data.require(name == 'payload/' and kind in (0, stat.S_IFDIR) and row.file_size == 0)
        else:
            data.require(kind in (0, stat.S_IFREG) and (name == 'artifact-manifest.json'
                         or re.fullmatch(r'payload/[0-9a-f]{64}\.(png|json)', name)))
            maximum = 4 * 1024 * 1024 if name == 'artifact-manifest.json' else data.MAX_FILE
            data.require(0 < row.file_size <= maximum)
            total += row.file_size
            data.require(total <= data.MAX_TOTAL)
    data.require('artifact-manifest.json' in seen)
    return rows


def unpack(archive, destination, identity, expected_sha256, expected_bytes):
    data.identity(identity)
    archive, destination = Path(archive), Path(destination)
    data.require(archive.resolve() == archive and not archive.is_symlink() and archive.is_file()
                 and destination.resolve() == destination and not destination.exists() and not destination.is_symlink()
                 and type(expected_bytes) is int and 0 < expected_bytes <= MAX_ARCHIVE
                 and archive.stat().st_size == expected_bytes
                 and isinstance(expected_sha256, str) and re.fullmatch('[0-9a-f]{64}', expected_sha256))
    with archive.open('rb') as stream:
        data.require(hashlib.file_digest(stream, 'sha256').hexdigest() == expected_sha256)
    made = False
    try:
        with zipfile.ZipFile(archive) as stream:
            rows = members(stream)
            destination.mkdir(parents=True); made = True
            (destination / 'payload').mkdir()
            for row in rows:
                if row.is_dir(): continue
                raw = stream.read(row)
                data.require(len(raw) == row.file_size)
                (destination / row.filename).write_bytes(raw)
        return captures.verify(destination, identity)
    except (OSError, ValueError, zipfile.BadZipFile, RuntimeError):
        if made: shutil.rmtree(destination)
        raise ValueError('Downloaded capture archive checksum, identity or integrity is invalid') from None
