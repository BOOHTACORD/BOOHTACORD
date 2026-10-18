"""Attest the executable actually running in this owned disposable API container."""
import hashlib
from pathlib import Path
import subprocess
import tempfile
from tools.qa.client_lifecycle.services import LABEL, output, run


def api_binary_sha256(stack):
    if not stack.api or ('container', stack.api) not in stack.resources:
        raise ValueError('An active owned API container is required')
    label = output('docker', 'inspect', stack.api,
                   '--format', '{{index .Config.Labels "' + LABEL + '"}}')
    if label != stack.owner:
        raise ValueError('Refusing to attest a foreign API container')
    with tempfile.TemporaryDirectory(prefix='api-identity-', dir=stack.work) as work:
        binary = Path(work) / 'api'
        run('docker', 'cp', stack.api + ':/api', str(binary), stdout=subprocess.DEVNULL)
        digest = hashlib.sha256()
        with binary.open('rb') as stream:
            for chunk in iter(lambda: stream.read(1024 * 1024), b''):
                digest.update(chunk)
        return digest.hexdigest()
