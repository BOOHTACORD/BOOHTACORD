"""Build a local-only v0.2 probe around the real capture processor."""
import argparse
import json
import subprocess
from pathlib import Path

from ..verify import check_output, checked_source

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[3]


def build(source, output, cmake, ctest):
    check_output(output)
    if output.exists():
        raise FileExistsError('Research output already exists')
    lock = json.loads((HERE.parent / 'lock.json').read_text(encoding='utf-8'))
    checked_source(source, lock)
    output.mkdir(parents=True, exist_ok=False)
    subprocess.run([cmake, '-S', str(HERE), '-B', str(output),
                    '-DRNNOISE_SOURCE=' + source.as_posix()], cwd=ROOT, check=True)
    subprocess.run([cmake, '--build', str(output), '--config', 'Release', '--parallel', '2'], check=True)
    subprocess.run([ctest, '--test-dir', str(output), '-C', 'Release',
                    '--no-tests=error', '--output-on-failure'], check=True)
    print('Local v0.2 capture processor probe passed; not a release artifact')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--cmake', default='cmake')
    parser.add_argument('--ctest', default='ctest')
    args = parser.parse_args()
    build(args.source.resolve(), args.output.resolve(), args.cmake, args.ctest)
