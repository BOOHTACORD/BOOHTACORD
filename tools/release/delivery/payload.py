"""Inspect exactly the immutable transport pair; remote signatures remain required."""
import hashlib
from pathlib import Path
import re

MAX_BUNDLE = 8_000_000_000


def inspect(directory, revision):
    try:
        root = Path(directory)
        if (not isinstance(revision, str) or not re.fullmatch('[a-f0-9]{40}', revision)
                or root.resolve() != root or root.is_symlink() or not root.is_dir()):
            raise ValueError
        name = revision + '.release.tar.gz'
        if {p.name for p in root.iterdir()} != {name, name + '.sha256'}:
            raise ValueError
        bundle, checksum = root/name, root/(name + '.sha256')
        for path, maximum in ((bundle, MAX_BUNDLE), (checksum, 256)):
            if (path.is_symlink() or path.resolve() != path or not path.is_file()
                    or path.stat().st_nlink != 1 or not 0 < path.stat().st_size <= maximum):
                raise ValueError
        with bundle.open('rb') as stream:
            digest = hashlib.file_digest(stream, 'sha256').hexdigest()
        if checksum.read_bytes() != (digest + '  ' + name + '\n').encode():
            raise ValueError
        return {'path': bundle, 'sha256': digest, 'bytes': bundle.stat().st_size}
    except (OSError, ValueError, TypeError):
        raise ValueError('Release transport identity, files or checksum differ') from None
