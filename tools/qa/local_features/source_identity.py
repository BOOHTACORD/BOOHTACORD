"""Fingerprint tracked and untracked source at report time without exposing contents."""
import hashlib
import os
import subprocess


def source_identity(root):
    def git(*args):
        return subprocess.check_output(['git', '-C', str(root), *args])

    head = git('rev-parse', 'HEAD').decode('ascii').strip()
    digest = hashlib.sha256()
    diff = git('diff', '--binary', 'HEAD', '--')
    digest.update(len(diff).to_bytes(8, 'big'))
    digest.update(diff)
    paths = sorted(filter(None, git('ls-files', '--others', '--exclude-standard', '-z').split(b'\0')))
    for raw in paths:
        path = root / os.fsdecode(raw)
        digest.update(len(raw).to_bytes(8, 'big'))
        digest.update(raw)
        if path.is_symlink():
            data = os.fsencode(os.readlink(path))
            digest.update(b'L' + len(data).to_bytes(8, 'big') + data)
        else:
            digest.update(b'F' + path.stat().st_size.to_bytes(8, 'big'))
            with path.open('rb') as stream:
                for chunk in iter(lambda: stream.read(1024 * 1024), b''):
                    digest.update(chunk)
    return head + ' worktree-sha256=' + digest.hexdigest()


def source_stability(before, after):
    return {'name': 'source-stability', 'status': 'PASS' if before == after else 'BLOCKED',
            'before': before, 'after': after}
