"""Private durable ownership journal; an exclusive controller may recover its orphan."""
import fcntl
import json
import os
from pathlib import Path
import re

OWNER = {'kind': 'boohtacord-server-builder-storage', 'version': 1}


def require(value):
    if not value:
        raise ValueError('Builder storage ownership or cleanup is unverified')


def validate(row):
    require(isinstance(row, dict) and set(row) == {'owner', 'image', 'revision', 'archive', 'daemon_sha256'})
    for field, length in (('owner', 32), ('revision', 40), ('archive', 64), ('daemon_sha256', 64)):
        require(isinstance(row[field], str) and re.fullmatch('[0-9a-f]{%d}' % length, row[field]))
    require(isinstance(row['image'], str) and re.fullmatch(r'moby/buildkit@sha256:[0-9a-f]{64}', row['image']))
    return row


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        require(key not in result)
        result[key] = value
    return result


class Lease:
    def __init__(self, root):
        self.root = Path(root)
        self.fd = None

    def __enter__(self):
        root = self.root
        require(root.is_absolute() and root.resolve() == root)
        fresh = not root.exists()
        if fresh:
            root.mkdir(mode=0o700, parents=True)
        require(root.is_dir() and root.stat().st_uid == os.getuid() and root.stat().st_mode & 0o777 == 0o700)
        if fresh:
            self.write('.owner.json', OWNER)
        allowed = {'.owner.json', '.lock', 'active.json', 'active.tmp'}
        for path in root.iterdir():
            require(path.name in allowed and not path.is_symlink() and path.is_file()
                    and path.stat().st_nlink == 1 and path.stat().st_uid == os.getuid()
                    and path.stat().st_size <= 8192 and path.stat().st_mode & 0o077 == 0)
        marker = self.read('.owner.json')
        require(marker == OWNER and type(marker['version']) is int)
        descriptor = os.open(root/'.lock', os.O_CREAT | os.O_RDWR | os.O_NOFOLLOW, 0o600)
        try:
            require(os.fstat(descriptor).st_nlink == 1 and os.fstat(descriptor).st_uid == os.getuid())
            fcntl.flock(descriptor, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BaseException:
            os.close(descriptor)
            raise ValueError('Builder controller lease is unavailable') from None
        self.fd = descriptor
        return self

    def read(self, name='active.json'):
        require(name in ('active.json', '.owner.json'))
        path = self.root/name
        require(not path.is_symlink())
        if not path.exists():
            return None
        require(not path.is_symlink() and path.is_file() and path.stat().st_nlink == 1
                and path.stat().st_uid == os.getuid() and path.stat().st_mode & 0o077 == 0
                and 0 < path.stat().st_size <= 8192)
        try:
            value = json.loads(path.read_bytes(), object_pairs_hook=unique_object)
        except (ValueError, OSError):
            raise ValueError('Builder ownership journal is invalid') from None
        return validate(value) if name == 'active.json' else value

    def write(self, name, value):
        require(name in ('.owner.json', 'active.tmp'))
        path = self.root/name
        descriptor = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
        with os.fdopen(descriptor, 'w') as stream:
            stream.write(json.dumps(value, sort_keys=True)+'\n')
            stream.flush()
            os.fsync(stream.fileno())

    def save(self, row):
        validate(row)
        active = self.root/'active.json'
        require(not active.exists() and not active.is_symlink())
        temporary = self.root/'active.tmp'
        require(not temporary.is_symlink())
        if temporary.exists():
            require(temporary.is_file() and temporary.stat().st_nlink == 1
                    and temporary.stat().st_uid == os.getuid() and temporary.stat().st_mode & 0o077 == 0)
            temporary.unlink()
        self.write('active.tmp', row)
        temporary.replace(self.root/'active.json')
        self.sync()

    def sync(self):
        descriptor = os.open(self.root, os.O_RDONLY | os.O_DIRECTORY)
        try:
            os.fsync(descriptor)
        finally:
            os.close(descriptor)

    def clear(self):
        require(self.read() is not None)
        (self.root/'active.json').unlink()
        self.sync()

    def __exit__(self, *_):
        if self.fd is not None:
            fcntl.flock(self.fd, fcntl.LOCK_UN)
            os.close(self.fd)
            self.fd = None
