"""Verify a downloaded ZIP against external identity and optionally restore frames."""
import argparse
from pathlib import Path
from . import archive, captures


def main(arguments=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--archive', required=True, type=Path)
    parser.add_argument('--sha256', required=True)
    parser.add_argument('--bytes', required=True, type=int)
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--restore', type=Path)
    for name in ('source-revision', 'run-id', 'run-attempt', 'namespace', 'component', 'profile', 'platform'):
        parser.add_argument('--' + name, required=True)
    args = parser.parse_args(arguments)
    identity = {'repository': 'BOOHTACORD/BOOHTACORD', **{key: getattr(args, key) for key in
                ('source_revision', 'run_id', 'run_attempt', 'namespace', 'component', 'profile', 'platform')}}
    try:
        value = archive.unpack(args.archive.absolute(), args.output.absolute(), identity, args.sha256, args.bytes)
        if args.restore is not None:
            captures.restore(args.output.absolute(), args.restore.absolute(), identity)
    except (ValueError, OSError, RuntimeError):
        print('FAIL: capture archive checksum, identity, integrity or restore destination')
        return 1
    print('PASS: downloaded capture integrity; logical files=' + str(len(value['files']))
          + '; original test verdict remains independent')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
