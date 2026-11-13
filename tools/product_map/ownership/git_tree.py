"""Read tracked runtime paths from an exact committed Git tree."""
import re
import subprocess

from .new_paths import RUNTIME_ROOTS


def tracked_files(root, sha):
    if not isinstance(sha, str) or not re.fullmatch(r'[0-9a-f]{40}', sha):
        raise ValueError('tree reference must be an exact commit SHA')
    result = subprocess.run(['git', 'ls-tree', '-r', '-z', '--name-only', sha, '--',
                             *RUNTIME_ROOTS], cwd=root, check=True,
                            stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    return [row.decode('utf-8', errors='strict') for row in result.stdout.split(b'\0') if row]
