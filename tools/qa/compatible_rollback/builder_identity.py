"""Bind cached QA artifacts to the actual trusted build-tool implementation."""
import hashlib

DIRECTORIES = ('tools/build/server', 'tools/build/web', 'tools/audio',
               'tools/verify/oci', 'tools/release/bundle', 'tools/release/archive')


def builder_hashes(root):
    result = {}
    for directory in DIRECTORIES:
        for path in sorted((root / directory).rglob('*.py')):
            if path.is_symlink():
                raise ValueError('Builder source must not contain Python symlinks')
            result[str(path.relative_to(root))] = hashlib.sha256(path.read_bytes()).hexdigest()
    return result


def cache_identity(proof, root):
    return {'sources': {role: proof[role]['head'] for role in ('current', 'previous')},
            'builder_sha256': builder_hashes(root)}
