"""Lossless content deduplication with exact-source verification and safe restore."""
import json
import re
import shutil
from pathlib import Path
from . import capture_data as data


def pack(files, destination, identity):
    data.identity(identity)
    destination = Path(destination)
    data.require(destination.resolve() == destination and not destination.exists() and not destination.is_symlink()
                 and isinstance(files, dict) and 0 < len(files) <= data.MAX_FILES)
    data.portable_paths(files)
    records, payloads, total = {}, {}, 0
    for name, path in sorted(files.items()):
        logical = data.logical_path(name)
        raw, digest = data.payload(Path(path), logical.suffix)
        total += len(raw)
        data.require(total <= data.MAX_TOTAL)
        blob = 'payload/' + digest + logical.suffix
        payloads[blob] = raw
        records[name] = {'payload': blob, 'bytes': len(raw), 'sha256': digest}
    value = {'schema_version': 1, 'kind': 'ci-synthetic-captures', 'integrity': 'PASS',
             'identity': dict(identity), 'files': records}
    destination.mkdir(parents=True)
    try:
        (destination / 'payload').mkdir()
        for name, raw in payloads.items():
            (destination / name).write_bytes(raw)
        (destination / 'artifact-manifest.json').write_text(json.dumps(value, sort_keys=True, indent=2) + '\n')
        verify(destination, identity)
    except Exception:
        shutil.rmtree(destination)
        raise
    return value


def verify(directory, expected_identity):
    data.identity(expected_identity)
    directory = Path(directory)
    data.require(not directory.is_symlink() and directory.is_dir()
                 and {p.name for p in directory.iterdir()} == {'artifact-manifest.json', 'payload'})
    document = directory / 'artifact-manifest.json'
    data.require(not document.is_symlink() and document.is_file() and 0 < document.stat().st_size <= 4 * 1024 * 1024)
    value = data.strict_json(document.read_bytes())
    data.require(isinstance(value, dict) and set(value) == {'schema_version', 'kind', 'integrity', 'identity', 'files'}
                 and type(value['schema_version']) is int and value['schema_version'] == 1
                 and value['kind'] == 'ci-synthetic-captures' and value['integrity'] == 'PASS'
                 and value['identity'] == expected_identity)
    files = value['files']
    data.require(isinstance(files, dict) and 0 < len(files) <= data.MAX_FILES)
    data.portable_paths(files)
    blobs, total = {}, 0
    for name, row in files.items():
        logical = data.logical_path(name)
        data.require(isinstance(row, dict) and set(row) == {'payload', 'sha256', 'bytes'}
                     and isinstance(row['sha256'], str) and re.fullmatch('[0-9a-f]{64}', row['sha256'])
                     and type(row['bytes']) is int and 0 < row['bytes'] <= data.MAX_FILE
                     and row['payload'] == 'payload/' + row['sha256'] + logical.suffix)
        total += row['bytes']
        data.require(total <= data.MAX_TOTAL)
        if row['payload'] in blobs:
            data.require(blobs[row['payload']] == (row['sha256'], row['bytes'], logical.suffix))
        blobs[row['payload']] = (row['sha256'], row['bytes'], logical.suffix)
    payload_root = directory / 'payload'
    data.require(not payload_root.is_symlink() and payload_root.is_dir()
                 and {p.relative_to(directory).as_posix() for p in payload_root.iterdir()} == set(blobs))
    for name, (digest, size, extension) in blobs.items():
        raw, actual = data.payload(directory / name, extension)
        data.require(actual == digest and len(raw) == size)
    return value


def restore(directory, destination, expected_identity):
    manifest = verify(directory, expected_identity)
    directory, destination = Path(directory).resolve(), Path(destination)
    data.require(destination.resolve() == destination and not destination.exists() and not destination.is_symlink()
                 and not destination.resolve().is_relative_to(directory))
    destination.mkdir(parents=True)
    try:
        for name, row in manifest['files'].items():
            target = destination / name
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(directory / row['payload'], target)
    except Exception:
        shutil.rmtree(destination)
        raise
