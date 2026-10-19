"""Bind cached QA artifacts to the actual trusted build-tool implementation."""
import hashlib

DIRECTORIES = ('tools/build/server', 'tools/build/web', 'tools/audio',
               'tools/verify/oci', 'tools/release/bundle', 'tools/release/archive')


def builder_hashes(root):
    result = {}
    toolchains = root / 'tools/toolchains.json'
    if toolchains.exists() or toolchains.is_symlink():
        if toolchains.is_symlink() or not toolchains.is_file():
            raise ValueError('Builder toolchain policy must be a regular source file')
        result['tools/toolchains.json'] = hashlib.sha256(toolchains.read_bytes()).hexdigest()
    for directory in DIRECTORIES:
        for path in sorted((root / directory).rglob('*')):
            if path.suffix not in ('.py', '.json'):
                continue
            if path.is_symlink():
                raise ValueError('Builder source must not contain Python symlinks')
            result[str(path.relative_to(root))] = hashlib.sha256(path.read_bytes()).hexdigest()
    return result


def cache_identity(proof, root):
    return {'sources': {role: proof[role]['head'] for role in ('current', 'previous')},
            'builder_sha256': builder_hashes(root)}
