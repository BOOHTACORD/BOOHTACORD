"""Resolve event revisions as Git arguments, never shell-interpolated filenames."""
import json
import os
import re
import subprocess
from pathlib import Path
from .selection import ALL, classify


def git(*args):
    return subprocess.run(['git', *args], capture_output=True, check=True).stdout


def changed_paths(event, event_name):
    if not isinstance(event, dict):
        return None
    if event_name == 'pull_request':
        base = event.get('pull_request', {}).get('base', {}).get('sha')
    elif event_name == 'push' and not str(event.get('ref', '')).startswith('refs/tags/'):
        base = event.get('before')
    else:
        return None
    if not isinstance(base, str) or not re.fullmatch('[0-9a-f]{40}', base) or base == '0' * 40:
        return None
    try:
        head = git('rev-parse', 'HEAD').decode().strip()
        if os.environ.get('GITHUB_SHA', head) != head:
            return None
        if event_name == 'pull_request':
            base = git('merge-base', base, head).decode().strip()
        paths = git('diff', '--name-only', '--no-renames', '-z', base, head, '--').decode('utf-8').split('\0')
        return [path for path in paths if path]
    except (subprocess.CalledProcessError, OSError, UnicodeError):
        return None


def main():
    try:
        event = json.loads(Path(os.environ['GITHUB_EVENT_PATH']).read_text(encoding='utf-8'))
        paths = changed_paths(event, os.environ.get('GITHUB_EVENT_NAME'))
    except (OSError, ValueError, KeyError, TypeError, AttributeError):
        paths = None
    from tools.ci.actual_acceptance.plan import select as acceptance
    risk=acceptance(paths)
    classification = classify(paths)
    chosen = classification.pop('gates')
    values = {name: name in chosen for name in sorted(ALL)}
    values.update(classification)
    values.update(actual_profiles=json.dumps(risk['profiles'],separators=(',',':')),
                  actual_required=bool(risk['profiles']),actual_map_sha256=risk['map_sha256'],
                  actual_release_required=json.dumps(risk['release_required'],separators=(',',':')),
                  actual_physical_required=json.dumps(risk['physical_required'],separators=(',',':')))
    result = ''.join(f'{name}={str(value).lower() if type(value) is bool else value}\n'
                     for name, value in values.items())
    with Path(os.environ['GITHUB_OUTPUT']).open('a', encoding='utf-8') as output:
        output.write(result)
    print(result, end='')


if __name__ == '__main__':
    main()
