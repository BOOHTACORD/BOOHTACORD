"""Read both sides of renames as paths from a verified Git diff."""
import re
import subprocess


def changed_paths(root, base):
    if not re.fullmatch(r'[0-9a-f]{40}', base):
        raise ValueError('impact base must be an exact lowercase commit SHA')
    result = subprocess.run(['git', 'diff', '--name-only', '-z', '--no-renames',
                             base + '...HEAD', '--'], cwd=root, check=True,
                            stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    return [part.decode('utf-8', errors='strict') for part in result.stdout.split(b'\0') if part]
