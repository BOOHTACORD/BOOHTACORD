"""Authenticate the retained real Flutter fixture for the fast monitor gate."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil


def prepare(directory, expected_source):
    record = json.loads((directory / 'artifact-manifest.json').read_text())
    if record['source_revision'] != expected_source or record['source_dirty']:
        raise ValueError('Windows native fixture source mismatch')
    for name, item in record['files'].items():
        relative = Path(name)
        if relative.is_absolute() or '..' in relative.parts:
            raise ValueError('Invalid native fixture path')
        file = directory / relative
        with file.open('rb') as stream:
            digest = hashlib.file_digest(stream, 'sha256').hexdigest()
        if digest != item['sha256'] or file.stat().st_size != item['bytes']:
            raise ValueError('Native fixture content mismatch')
    # The retained first candidate exposed the SDK archive/loader-name mismatch.
    # Keep that exact real app as a fixture, supplying its authenticated SDK DLL
    # at the PE-required name, as the corrected production CMake does.
    sdk = directory / 'velopack_libc_win_x64_msvc.dll'
    if sdk.exists() and not (directory / 'velopack_libc.dll').exists():
        shutil.copy2(sdk, directory / 'velopack_libc.dll')


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--directory', type=Path, required=True)
    parser.add_argument('--expected-source', required=True)
    args = parser.parse_args()
    prepare(args.directory, args.expected_source)
