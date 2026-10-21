"""Decode exactly the three bounded, direct and unambiguous release receipts."""
import json
import re
from pathlib import Path

GATES = ('backend', 'web', 'contracts')
FIELDS = {'source_revision', 'gate', 'status'}


def unique(pairs):
    value = {}
    for key, item in pairs:
        if key in value:
            raise ValueError('Duplicate gate receipt field')
        value[key] = item
    return value


def read(directory, revision):
    try:
        if (not isinstance(revision, str) or not re.fullmatch('[0-9a-f]{40}', revision)
                or directory.is_symlink() or not directory.is_dir()
                or {p.name for p in directory.iterdir()} != {gate + '.json' for gate in GATES}):
            raise ValueError('Invalid gate receipt set')
        result = {}
        for gate in GATES:
            path = directory / (gate + '.json')
            if path.is_symlink() or not path.is_file() or not 0 < path.stat().st_size <= 4096:
                raise ValueError('Invalid gate receipt file')
            receipt = json.loads(path.read_text(encoding='utf-8'), object_pairs_hook=unique)
            if (not isinstance(receipt, dict) or set(receipt) != FIELDS
                    or receipt['source_revision'] != revision or receipt['gate'] != gate
                    or receipt['status'] != 'PASS'):
                raise ValueError('Invalid gate receipt identity or result')
            result[gate] = 'PASS'
        return result
    except (OSError, ValueError, TypeError):
        raise ValueError('Release requires exactly three direct, bounded, unique PASS receipts for this source') from None


def collect(downloaded, destination, revision, run_id, run_attempt):
    """Select the latest available PASS receipt per gate from this exact workflow run."""
    downloaded, destination = Path(downloaded), Path(destination)
    if (not isinstance(revision, str) or not re.fullmatch('[0-9a-f]{40}', revision)
            or not isinstance(run_id, str) or not re.fullmatch('[1-9][0-9]*', run_id)
            or type(run_attempt) is not int or run_attempt < 1
            or downloaded.is_symlink() or not downloaded.is_dir()
            or destination.exists() or destination.is_symlink()
            or destination.parent.is_symlink() or not destination.parent.is_dir()):
        raise ValueError('Invalid gate artifact collection context')

    candidates = {gate: [] for gate in GATES}
    try:
        for artifact in downloaded.iterdir():
            if artifact.is_symlink() or not artifact.is_dir():
                raise ValueError('Invalid gate artifact entry')
            match = None
            for gate in GATES:
                expected = re.fullmatch(
                    rf'check-{gate}-{re.escape(revision)}-{re.escape(run_id)}-([1-9][0-9]*)',
                    artifact.name)
                if expected:
                    match = (gate, int(expected.group(1)))
                    break
            if match is None or match[1] > run_attempt:
                raise ValueError('Gate artifact does not belong to this workflow execution')
            candidates[match[0]].append((match[1], artifact))

        selected = {}
        for gate, artifacts in candidates.items():
            if not artifacts:
                raise ValueError('A required gate artifact is missing')
            attempt = max(item[0] for item in artifacts)
            matching = [path for number, path in artifacts if number == attempt]
            if len(matching) != 1:
                raise ValueError('Ambiguous gate artifact attempt')
            artifact = matching[0]
            if {entry.name for entry in artifact.iterdir()} != {gate + '.json'}:
                raise ValueError('Invalid gate artifact contents')
            receipt = artifact / (gate + '.json')
            if receipt.is_symlink() or not receipt.is_file() or not 0 < receipt.stat().st_size <= 4096:
                raise ValueError('Invalid gate artifact receipt')
            selected[gate] = receipt.read_bytes()

        destination.mkdir()
        for gate in GATES:
            (destination / (gate + '.json')).write_bytes(selected[gate])
        return read(destination, revision)
    except (OSError, ValueError, TypeError):
        if destination.is_dir() and not destination.is_symlink():
            for child in destination.iterdir():
                if child.is_file() and not child.is_symlink():
                    child.unlink()
            destination.rmdir()
        raise ValueError('Release requires unambiguous PASS receipts from this source and workflow run') from None


def main():
    import argparse
    import os
    parser = argparse.ArgumentParser()
    parser.add_argument('--collect', action='store_true')
    parser.add_argument('downloaded')
    parser.add_argument('destination')
    arguments = parser.parse_args()
    if not arguments.collect:
        parser.error('--collect is required')
    result = collect(arguments.downloaded, arguments.destination,
                     os.environ.get('GATE_SOURCE_REVISION'), os.environ.get('GATE_RUN_ID'),
                     int(os.environ.get('GATE_RUN_ATTEMPT', '0')))
    print(json.dumps(result, sort_keys=True))


if __name__ == '__main__':
    main()
