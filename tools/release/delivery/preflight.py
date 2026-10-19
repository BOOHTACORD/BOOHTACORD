"""One exact producer/artifact authority before and after artifact download."""
from .provenance import validate
from .routing import decision
from .producer_artifacts import select

_UNSET = object()


def verified(reader, repository, run_id, revision=None, *, expected=_UNSET):
    run = reader.read()
    source = validate(run, repository, revision)
    route = decision(run, reader.collection('jobs'), repository)
    if not route['has_bundle']:
        raise ValueError('Producer has no successful release bundle')
    artifact = select(int(run_id), run, reader.collection('artifacts'), repository, route['format_version'] == 2)
    after = reader.read()
    validate(after, repository, source)
    if any(after.get(key) != run.get(key) for key in ('id', 'run_attempt', 'repository', 'head_repository')):
        raise ValueError('Producer execution changed during preflight')
    if expected is not _UNSET and (not isinstance(expected, dict) or artifact != expected):
        raise ValueError('Producer artifact changed during download')
    return artifact
