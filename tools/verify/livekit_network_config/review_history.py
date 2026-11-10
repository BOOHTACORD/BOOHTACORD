"""Verify source-only reviews against the revisions they recorded."""
import hashlib

from .historical_artifact import evidence_content

REVIEWS = {
    'livekit-network-recovery-review-2026-11-09.json': 'e565420073483c7234202817eecf362cf754e844',
    'livekit-network-roster-retry-2026-11-09.json': 'd85b56aad5b028ce66f9e23bda97b872c76fb166',
    'livekit-network-recovery-roster-integration-2026-11-09.json': 'be97f71727a6d263390ebe13c30ad93228c71760',
    'livekit-network-transfer-recovery-2026-11-09.json': 'c96af5782b34d968fbc43de831cf816840316de5',
}


def verify_review(root, revision, artifacts):
    for path, expected in artifacts.items():
        content = evidence_content(root, revision, path).replace(b'\r\n', b'\n')
        if expected != 'sha256:' + hashlib.sha256(content).hexdigest():
            raise ValueError(f'review artifact hash differs for {path}')
