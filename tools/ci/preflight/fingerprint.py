"""Bind manual review to Git state and the bytes of untracked files."""
import hashlib
import os
from pathlib import Path

from tools.ci.preflight.inventory import git


def snapshot(root, changes):
    digest = hashlib.sha256()
    for args in (('diff', '--binary', changes['merge_base'], 'HEAD', '--'),
                 ('diff', '--binary', '--cached', '--'), ('diff', '--binary', '--')):
        data = git(root, *args)
        digest.update(len(data).to_bytes(8, 'big'))
        digest.update(data)
    digest.update(changes['base_commit'].encode('ascii'))
    digest.update(changes['merge_base'].encode('ascii'))
    digest.update(git(root, 'rev-parse', 'HEAD').strip())
    for name in changes['untracked']:
        path = Path(root) / name
        digest.update(name.encode('utf-8') + b'\0')
        digest.update(str(path.lstat().st_mode).encode('ascii') + b'\0')
        content = hashlib.sha256()
        if path.is_symlink():
            content.update(os.readlink(path).encode('utf-8'))
        else:
            with path.open('rb') as stream:
                for chunk in iter(lambda: stream.read(1024 * 1024), b''):
                    content.update(chunk)
        digest.update(content.digest())
    return digest.hexdigest()
