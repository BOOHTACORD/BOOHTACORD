"""Require a named local checkout and disclose every tracked/untracked change."""
import re
from pathlib import Path

from tools.qa.client_lifecycle.services import output


def source_identity(root, allow_dirty_smoke=False, git=output):
    root = Path(root).resolve()
    if not (root / '.git').exists():
        raise ValueError('Source must be a checkout root')
    revision = git('git', '-C', str(root), 'rev-parse', 'HEAD')
    if not re.fullmatch(r'[a-f0-9]{40}', revision):
        raise ValueError('Source revision is invalid')
    dirty = bool(git('git', '-C', str(root), 'status', '--porcelain', '--untracked-files=all'))
    if dirty and not allow_dirty_smoke:
        raise ValueError('Dirty source is allowed only for explicitly marked smoke')
    return revision, not dirty
