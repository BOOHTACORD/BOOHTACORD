"""Persist and revalidate the exact artifact authority across a pinned download."""
import json
import os
import sys
from pathlib import Path
from .api import Reader
from .payload import inspect
from .preflight import verified


def target(path):
    path = Path(path)
    if not path.is_absolute() or path.parent.resolve() != path.parent or path.is_symlink():
        raise ValueError('Delivery snapshot path is not canonical')
    return path


def accepted(*, expected=None, compare=False):
    repository, run_id = os.environ['GITHUB_REPOSITORY'], os.environ['BUILD_RUN_ID']
    reader = Reader(repository, run_id, os.environ['GITHUB_TOKEN'])
    arguments = {'expected': expected} if compare else {}
    return verified(reader, repository, run_id, os.environ.get('REQUESTED_REVISION') or None, **arguments)


def prepare(snapshot, output):
    snapshot = target(snapshot)
    if snapshot.exists():
        raise FileExistsError('Delivery snapshot already exists')
    value = accepted()
    descriptor = os.open(snapshot, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
    with os.fdopen(descriptor, 'w', encoding='utf-8') as stream:
        stream.write(json.dumps(value, sort_keys=True) + '\n')
    with open(output, 'a', encoding='utf-8') as stream:
        for key, original in (('revision', 'source_revision'), ('run_id', 'run_id'), ('run_attempt', 'run_attempt'),
                              ('artifact_id', 'id'), ('artifact_name', 'name')):
            stream.write(f'{key}={value[original]}\n')


def load(snapshot):
    snapshot = target(snapshot)
    if not snapshot.is_file() or snapshot.stat().st_nlink != 1 or not 0 < snapshot.stat().st_size <= 8192:
        raise ValueError('Invalid delivery snapshot')
    value = json.loads(snapshot.read_bytes())
    if not isinstance(value, dict): raise ValueError('Invalid delivery snapshot document')
    return value


def recheck(snapshot, incoming):
    value = accepted(expected=load(snapshot), compare=True)
    inspect(incoming, value['source_revision'])
    return value


def main():
    root = Path.cwd()/'.out/delivery'
    root.mkdir(parents=True, exist_ok=True)
    snapshot = root/'producer.json'
    if sys.argv[1:] == ['prepare']:
        prepare(snapshot, os.environ['GITHUB_OUTPUT'])
    elif sys.argv[1:] == ['recheck']:
        recheck(snapshot, Path.cwd()/'.out/incoming')
    else:
        raise ValueError('Unknown delivery authority operation')
    print('Verified immutable producer artifact authority')


if __name__ == '__main__': main()
