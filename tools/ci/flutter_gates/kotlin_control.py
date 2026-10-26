"""Run the verified historical benchmark script independently of current checks."""
from pathlib import Path
import tempfile


def execute(source, run, root):
    # Preserve the original script's dirname-based repository lookup. This owned
    # sibling exists only during the historical control and is always removed.
    directory = root / 'tools/verify/android_kotlin'
    with tempfile.NamedTemporaryFile(dir=directory, prefix='.legacy-kotlin-',
                                     suffix='.sh', delete=False) as stream:
        stream.write(source)
        path = Path(stream.name)
    try:
        run('bash', str(path))
    finally:
        path.unlink()
    return ['kotlin-modes']
