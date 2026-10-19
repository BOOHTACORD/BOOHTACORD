"""Stable public role names bind native artifacts to one exact execution."""
import re

PREFIXES = {'windows-distribution': 'BOOHTACORD-windows-x64',
            'windows-installer': 'BOOHTACORD-windows-installer-x64',
            'windows-recovery': 'desktop-recovery-windows',
            'windows-acceptance': 'screen-setup-windows'}


def execution_name(role, source, run_id, attempt):
    if (role not in PREFIXES or not isinstance(source, str) or not re.fullmatch('[0-9a-f]{40}', source)
            or not isinstance(run_id, str) or not re.fullmatch('[1-9][0-9]{0,19}', run_id)
            or not isinstance(attempt, str) or not re.fullmatch('[1-9][0-9]{0,3}', attempt)):
        raise ValueError('Artifact role and exact source/run/attempt are required')
    return f'{PREFIXES[role]}-{source}-{run_id}-{attempt}'
