"""Build the isolated native PCM parity probe, not a release binary."""
import argparse
import json
from pathlib import Path
import subprocess

from .verify import checked_source, check_output

HERE = Path(__file__).resolve().parent


def build(source, output, cmake):
    check_output(output)
    lock = json.loads((HERE / 'lock.json').read_text(encoding='utf-8'))
    checked_source(source, lock)
    output.mkdir(parents=True, exist_ok=False)
    subprocess.run([cmake, '-S', str(HERE), '-B', str(output),
                    '-DRNNOISE_SOURCE=' + source.as_posix()], check=True)
    subprocess.run([cmake, '--build', str(output), '--config', 'Release', '--parallel', '2'], check=True)
    print('Research binary built; no client or release acceptance implied.')


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--source', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--cmake', default='cmake')
    args = parser.parse_args()
    build(args.source.resolve(), args.output.resolve(), args.cmake)
