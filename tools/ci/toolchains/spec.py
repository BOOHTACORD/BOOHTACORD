"""Read approved public SDK inputs without a YAML or installed-SDK dependency."""
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[3]


def public_bytes(root, name):
    root = root.resolve()
    path = root / name
    if path.is_symlink() or path.resolve() != path or not path.is_file():
        raise ValueError('Missing or indirect public toolchain/cache input')
    return path.read_bytes()


def approved_versions(root):
    source = json.loads(public_bytes(root, 'tools/toolchains.json'))
    selected = {name: source.get(name) for name in ('node', 'go', 'flutter', 'dart')}
    if any(not isinstance(v, str) or not re.fullmatch(r'[0-9]+\.[0-9]+\.[0-9]+', v)
           for v in selected.values()):
        raise ValueError('Exact approved SDK versions are required')
    if public_bytes(root, '.node-version').decode().strip() != selected['node']:
        raise ValueError('Node version file differs from the approved SDK')
    module = '\n'.join(' '.join(line.split('//', 1)[0].split())
                       for line in public_bytes(root, 'backend/go.mod').decode().splitlines())
    toolchain = re.findall(r'^toolchain go([0-9.]+)$', module, re.MULTILINE)
    minimum = re.findall(r'^go ([0-9]+\.[0-9]+(?:\.[0-9]+)?)$', module, re.MULTILINE)
    if toolchain != [selected['go']] or len(minimum) != 1:
        raise ValueError('Go module toolchain differs from the approved SDK')
    baseline = tuple(map(int, (minimum[0] + '.0').split('.')[:3]))
    if baseline > tuple(map(int, selected['go'].split('.'))):
        raise ValueError('Go module minimum exceeds the approved SDK')
    return selected
