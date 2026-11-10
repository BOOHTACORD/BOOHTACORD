"""Read the prior catalog directly from the immutable Git base commit."""
import re
import subprocess

from tools.product_map.release.publication import parse_record

PATH = re.compile(r'product-map/features/[a-z0-9_-]+/[a-z0-9_.-]+\.yaml\Z')


def _git(root, *args):
    return subprocess.run(['git', *args], cwd=root, check=True,
                          stdout=subprocess.PIPE, stderr=subprocess.PIPE).stdout


def read_previous_catalog(root, base):
    if not re.fullmatch(r'[0-9a-f]{40}', base):
        raise ValueError('catalog base must be an exact lowercase commit SHA')
    _git(root, 'cat-file', '-e', base + '^{commit}')
    raw = _git(root, 'ls-tree', '-r', '-z', '--full-tree', base, '--', 'product-map/features/')
    result = {'features': [], 'components': []}
    seen = {'features': set(), 'components': set()}
    for entry in filter(None, raw.split(b'\0')):
        header, name = entry.split(b'\t', 1)
        mode, kind, _ = header.decode('ascii').split(' ')
        path = name.decode('utf-8', errors='strict')
        if mode not in ('100644', '100755') or kind != 'blob' or not PATH.fullmatch(path):
            raise ValueError(f'unsafe or unexpected baseline catalog path: {path}')
        doc = parse_record(_git(root, 'show', base + ':' + path))
        for key in result:
            for item in doc[key]:
                identifier = item['id']
                if identifier in seen[key]:
                    raise ValueError(f'duplicate baseline {key} ID: {identifier}')
                seen[key].add(identifier)
                result[key].append(item)
    return result
