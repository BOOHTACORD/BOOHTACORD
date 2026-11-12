"""Validate source identities before an isolated, non-release build."""
import hashlib
import subprocess


def checked_file(path, expected):
    if hashlib.sha256(path.read_bytes()).hexdigest() != expected:
        raise ValueError(f'checksum mismatch: {path.name}')


def checked_source(source, lock):
    commit = subprocess.check_output(['git', '-C', str(source), 'rev-parse', 'HEAD'], text=True).strip()
    if commit != lock['sourceCommit']:
        raise ValueError('upstream commit mismatch')
    subprocess.run(['git', '-C', str(source), 'diff', '--quiet', 'HEAD', '--', 'src', 'include'], check=True)
    if (source / 'src/os_support.h').exists():
        raise ValueError('unexpected source-local os_support.h shadows the research shim')
    checked_file(source / 'src/rnnoise_data.c', lock['modelSha256'])
    checked_file(source / 'src/rnnoise_data.h', lock['modelHeaderSha256'])
