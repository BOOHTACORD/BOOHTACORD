"""Read an immutable source revision for historical evidence verification."""
import re
import subprocess
from pathlib import PurePosixPath

HISTORICAL_ARTIFACTS = frozenset({
    'backlog/tasks.yaml', 'tools/qa/local_features/features.json',
    'tools/verify/livekit_network_config/check.py',
})


def evidence_content(root, revision, path):
    validate_path(path)
    if path in HISTORICAL_ARTIFACTS:
        return content_at_revision(root, revision, path)
    return (root / path).read_bytes()


def validate_path(path):
    parts = PurePosixPath(path)
    if not path or parts.is_absolute() or '..' in parts.parts or ':' in path or '\\' in path:
        raise ValueError('Unsupported historical source')


def content_at_revision(root, revision, path):
    validate_path(path)
    if not re.fullmatch(r'[0-9a-f]{40}', revision):
        raise ValueError('Unsupported historical revision')
    try:
        return subprocess.check_output(['git', '-C', str(root), 'show', f'{revision}:{path}'],
                                       stderr=subprocess.DEVNULL)
    except (OSError, subprocess.CalledProcessError) as error:
        raise RuntimeError('Historical source is unavailable') from error
