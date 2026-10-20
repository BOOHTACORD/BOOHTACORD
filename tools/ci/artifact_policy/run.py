"""Publish only bounded synthetic captures from a fresh owned hosted execution."""
import argparse
import os
import shutil
import subprocess
from tools.ci.native.process import ROOT
from . import capture_inventory, publication, publication_context


def main(arguments=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('operation', choices=('begin', 'finish'))
    parser.add_argument('component', choices=('web', 'flutter'))
    parser.add_argument('profile', choices=('browser-shell', 'browser-content', 'browser-voice', 'browser-conversations', 'dart'))
    args = parser.parse_args(arguments)
    made = None
    try:
        identity = publication_context.checked(os.environ, args.component, args.profile)
        if args.operation == 'begin':
            capture_inventory.begin(ROOT, identity)
        else:
            made = publication.finish(ROOT, identity, os.environ.get('CAPTURE_UPSTREAM_STATUS'))
            final = publication_context.checked(os.environ, args.component, args.profile)
            if final != identity:
                raise ValueError('Capture execution changed during packaging')
    except (ValueError, OSError, RuntimeError, subprocess.SubprocessError):
        if made is not None:
            shutil.rmtree(made)
        print('FAIL: synthetic capture publication context, freshness, privacy or integrity')
        return 1
    print('PASS: synthetic capture ' + args.operation + '; test verdict remains independent')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
