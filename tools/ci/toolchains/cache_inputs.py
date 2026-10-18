"""Prepare public, versioned cache manifests before SDK setup; standard library only."""
import argparse
import hashlib
import json
import os
import platform
from .spec import ROOT, approved_versions, public_bytes

FILES = {'npm': ('.node-version', 'clients/web/package.json', 'clients/web/package-lock.json'),
         'go': ('backend/go.mod', 'backend/go.sum')}
SDK = {'npm': 'node', 'go': 'go'}


def payload(kind, root, operating_system, architecture):
    if (kind not in FILES or operating_system not in ('Linux', 'Windows', 'macOS')
            or architecture not in ('X64', 'ARM64')):
        raise ValueError('Unsupported cache kind, operating system or architecture')
    versions = approved_versions(root)
    return {'schema_version': 1, 'kind': kind, 'toolchain': versions[SDK[kind]],
            'platform': operating_system, 'architecture': architecture,
            'files': {name: hashlib.sha256(public_bytes(root, name)).hexdigest()
                      for name in FILES[kind]}}


def write_manifest(kind, root, operating_system, architecture):
    value = payload(kind, root, operating_system, architecture)
    root = root.resolve()
    directory = root / '.out/ci/cache-inputs'
    if directory.resolve() != directory:
        raise ValueError('Refusing an indirect cache manifest output directory')
    directory.mkdir(parents=True, exist_ok=True)
    target = directory / (kind + '.json')
    if target.is_symlink():
        raise ValueError('Refusing an indirect cache manifest output')
    with target.open('w', encoding='utf-8', newline='\n') as stream:
        stream.write(json.dumps(value, sort_keys=True, indent=2) + '\n')
    return target


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('kind', choices=FILES)
    args = parser.parse_args()
    system = os.environ.get('RUNNER_OS', {'Darwin': 'macOS'}.get(platform.system(), platform.system()))
    architecture = os.environ.get('RUNNER_ARCH', {'x86_64': 'X64', 'AMD64': 'X64',
                                                 'arm64': 'ARM64', 'aarch64': 'ARM64'}.get(platform.machine(), ''))
    write_manifest(args.kind, ROOT, system, architecture)
    print('Prepared public cache inputs: ' + args.kind)


if __name__ == '__main__':
    main()
