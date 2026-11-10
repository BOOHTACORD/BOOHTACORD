"""Verify the recovery review against its immutable source snapshot."""
import hashlib

from .historical_artifact import evidence_content

RECOVERY_REVISION = 'e565420073483c7234202817eecf362cf754e844'


def verify_recovery_evidence(root, artifacts):
    for path, expected in artifacts.items():
        content = evidence_content(root, RECOVERY_REVISION, path)
        actual = hashlib.sha256(content.replace(b'\r\n', b'\n')).hexdigest()
        if expected != f'sha256:{actual}':
            raise ValueError(f'recovery review artifact hash differs for {path}')
