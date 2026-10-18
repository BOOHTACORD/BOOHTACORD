"""Best-effort local Git classification, without fetching PR code or executing it."""
import re
import subprocess
from tools.ci.select_changes.selection import select


def components(head, event, repository):
    unknown = {'status': 'N/A', 'reason': 'source/base unavailable in local Git', 'gates': None}
    if not isinstance(head, str) or not re.fullmatch('[0-9a-f]{40}', head):
        return unknown
    try:
        parents = subprocess.check_output(['git', '-C', str(repository), 'rev-list', '--parents', '-n', '1', head],
                                          stderr=subprocess.DEVNULL, text=True).split()
        # A PR Actions head may be a feature head, not its tested merge commit.
        # Do not mislabel its last commit as the complete PR diff.
        if event != 'push' or len(parents) < 2:
            return unknown
        result = subprocess.run(['git', '-C', str(repository), 'diff', '--name-only', '--no-renames', '-z',
                                 parents[1], head, '--'], capture_output=True, check=True)
        paths = [x for x in result.stdout.decode().split('\0') if x]
        return {'status': 'observed', 'basis': 'push head vs first parent (not event.before)',
                'gates': sorted(select(paths))}
    except (subprocess.CalledProcessError, OSError, UnicodeError):
        return unknown
