"""Verify the external research source before native client configuration."""
import json
from pathlib import Path
import sys

from ..verify import checked_source


def main():
    if len(sys.argv) != 2:
        raise ValueError('A research source path is required')
    lock = json.loads((Path(__file__).resolve().parents[1] / 'lock.json').read_text(encoding='utf-8'))
    checked_source(Path(sys.argv[1]).resolve(), lock)


if __name__ == '__main__':
    main()
