"""Fail closed unless snapshot inputs match a clean, exact Git source."""
import re
import subprocess


def require_exact_source(root, revision):
    if not isinstance(revision, str) or not re.fullmatch(r'[0-9a-f]{40}', revision):
        raise ValueError('invalid source revision')
    try:
        actual = subprocess.check_output(['git', '-C', str(root), 'rev-parse',
                                          '--verify', 'HEAD^{commit}'], text=True).strip()
        status = subprocess.run(['git', '-C', str(root), 'diff', '--quiet', 'HEAD', '--'],
                                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        tracked = subprocess.check_output(['git', '-C', str(root), 'ls-files', '-z', '--',
                                           'product-map/features', 'tools/product_map',
                                           'tools/qa/local_features/features.json'])
    except (OSError, subprocess.CalledProcessError) as error:
        raise ValueError('source repository unavailable') from error
    if actual != revision:
        raise ValueError('source revision differs from checkout')
    if status.returncode != 0:
        raise ValueError('source checkout is dirty or unavailable')
    known = set(tracked.decode('utf-8').split('\0'))
    candidates = list((root / 'product-map/features').glob('*/*.yaml'))
    candidates += list((root / 'tools/product_map').rglob('*.py'))
    if any(path.relative_to(root).as_posix() not in known for path in candidates):
        raise ValueError('untracked catalog or generator input')
