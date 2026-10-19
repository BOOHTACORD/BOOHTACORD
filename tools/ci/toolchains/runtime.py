"""Check the actually selected auxiliary executable; never print its environment."""
import argparse
import os
import platform
import re
import subprocess
from .auxiliary import ROOT, check_runtime


def measured(kind):
    if kind == 'python':
        return platform.python_version()
    command = ['java', '-XshowSettings:properties', '-version'] if kind == 'java' else ['dotnet', '--version']
    result = subprocess.run(command, text=True, stdout=subprocess.PIPE,
                            stderr=subprocess.STDOUT, check=True, timeout=30)
    if kind == 'java':
        found = re.findall(r'^\s*java.runtime.version = (\S+)\s*$', result.stdout, re.MULTILINE)
        if len(found) != 1:
            raise ValueError('Java runtime identity unavailable')
        return found[0]
    return result.stdout.strip()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('kind', choices=('python', 'java', 'dotnet'))
    args = parser.parse_args()
    system = os.environ.get('RUNNER_OS', {'Darwin': 'macOS'}.get(platform.system(), platform.system()))
    actual = measured(args.kind)
    if not re.fullmatch(r'[0-9][0-9A-Za-z.+_-]{0,79}', actual):
        raise ValueError('Invalid public SDK version format')
    print('Selected ' + args.kind + ' runtime: ' + actual + ' (' + system + ')')
    check_runtime(args.kind, actual, system, ROOT)
    print('PASS installed ' + args.kind + ': ' + actual + ' (' + system + ')')


if __name__ == '__main__':
    main()
