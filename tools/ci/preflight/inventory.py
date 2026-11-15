"""Collect all candidate changes without interpreting Git's quoted paths."""
import subprocess


def git(root, *args):
    return subprocess.run(['git', *args], cwd=root, check=True, capture_output=True).stdout


def paths(root, *args):
    data = git(root, *args)
    return sorted(p.decode('utf-8') for p in data.split(b'\0') if p)


def inventory(root, base):
    base_commit = git(root, 'rev-parse', '--verify', '--end-of-options', f'{base}^{{commit}}').decode('ascii').strip()
    merge_base = git(root, 'merge-base', base_commit, 'HEAD').decode('ascii').strip()
    committed = paths(root, 'diff', '--name-only', '--no-renames', '-z', merge_base, 'HEAD', '--')
    staged = paths(root, 'diff', '--cached', '--name-only', '--no-renames', '-z', '--')
    unstaged = paths(root, 'diff', '--name-only', '--no-renames', '-z', '--')
    untracked = paths(root, 'ls-files', '--others', '--exclude-standard', '-z')
    return {'base': base, 'base_commit': base_commit, 'merge_base': merge_base, 'committed': committed,
            'staged': staged, 'unstaged': unstaged, 'untracked': untracked,
            'paths': sorted(set(committed + staged + unstaged + untracked))}
