"""Linux-only entrypoint inside the dedicated owned daemon container."""
import json
from pathlib import Path
import sys
import subprocess

work = Path('/qa')
sys.path.insert(0, str(work / 'current'))


def main():
    for role in ('current', 'previous'):
        subprocess.run(['git', 'config', '--global', '--add', 'safe.directory', str(work / role)], check=True)
    if sys.argv[1:] == ['prepare']:
        from build import build
        from setup import prepare
        build(work)
        prepare(work)
        (work / 'ready.json').write_text(json.dumps({'status': 'READY'}))
    elif sys.argv[1:] == ['rehearse']:
        from rehearse import rehearse
        rehearse(work)
    else:
        raise ValueError('Explicit owned phase required')


if __name__ == '__main__':
    main()
