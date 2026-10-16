"""Keep the owned real updater acceptance stack alive until explicit cleanup."""
import json
from pathlib import Path
from tools.ci.native.process import ROOT
from .stack import Stack


def main():
    root = ROOT / '.out/issue337/acceptance'
    root.mkdir(mode=0o700, exist_ok=False)
    stack = Stack(ROOT, root / 'stack')
    try:
        stack.start()
        private = root / 'native-private.json'
        private.write_text(json.dumps(stack.private_configuration(), indent=2) + '\n')
        private.chmod(0o600)
        state = root / 'runtime.json'
        state.write_text(json.dumps({'owner': stack.owner, 'resources': stack.resources,
                                     'api': stack.api, 'origin': 'https://localhost:4910',
                                     'source': '34274936', 'status': 'RUNNING'}, indent=2) + '\n')
        state.chmod(0o600)
        print('READY: owned HTTPS API, PostgreSQL and SFU; credentials saved privately')
    except BaseException:
        stack.close()
        raise


if __name__ == '__main__':
    main()
