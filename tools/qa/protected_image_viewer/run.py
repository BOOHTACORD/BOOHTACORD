"""Exercise real protected TEXT/DM images on one owned, disposable API stack."""
import json
import os
import subprocess
import tempfile
from pathlib import Path
from tools.qa.client_lifecycle.stack import Stack


def main():
    root = Path(__file__).resolve().parents[3]
    destination = root / '.out/protected-image-viewer'
    destination.mkdir(parents=True, exist_ok=True)
    environment = dict(os.environ, QA_ORIGIN='https://localhost:4810')
    with tempfile.TemporaryDirectory(prefix='private-', dir=destination) as private:
        work = Path(private)
        stack = Stack(root, work)
        try:
            stack.start()
            payload = work / 'input.json'
            payload.write_text(json.dumps({'password': stack.password, 'directory': str(destination)}))
            payload.chmod(0o600)
            environment.update(QA_INPUT=str(payload), QA_RESULT=str(destination/'result.json'))
            subprocess.run(['node', 'tools/qa/protected_image_viewer/scenario.mjs'], cwd=root,
                           env=environment, check=True, timeout=300)
        finally:
            stack.close()
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
