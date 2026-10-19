"""Attest only the complete exact-master server or native quality scope."""
import argparse
import json
import os
import subprocess
from pathlib import Path
from tools.ci.select_changes.selection import dependency_map
from . import context, validation

ROOT = Path(__file__).resolve().parents[3]


def identity():
    source = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()
    clean = subprocess.run(['git', 'diff', '--quiet', 'HEAD', '--'], cwd=ROOT).returncode == 0
    return source, clean


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('scope', choices=('server', 'native'))
    args = parser.parse_args()
    destination = ROOT / f'.out/ci/master-{args.scope}.json'
    destination.parent.mkdir(parents=True, exist_ok=True)
    if destination.is_symlink() or destination.parent.resolve() != destination.parent:
        raise ValueError('Master evidence path must be direct')
    destination.write_text(json.dumps({'status': 'FAIL', 'scope': args.scope}) + '\n')
    try:
        binding = context.validate(os.environ, *identity())
        digest = dependency_map()[1]
        needs = json.loads(os.environ['MASTER_NEEDS'])
        result = getattr(validation, args.scope)(needs, digest)
        value = {**result, **binding, 'scope': args.scope, 'map_sha256': digest,
                 'schema_version': 1, 'jobs': {name: entry['result'] for name, entry in needs.items()}}
        if context.validate(os.environ, *identity()) != binding:
            raise ValueError('Master source changed during validation')
    except (ValueError, KeyError, TypeError, OSError):
        print('FAIL: master quality lacks exact source and all required successful jobs')
        return 1
    destination.write_text(json.dumps(value, sort_keys=True) + '\n')
    print('PASS: exact-master ' + args.scope + ' quality complete')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
