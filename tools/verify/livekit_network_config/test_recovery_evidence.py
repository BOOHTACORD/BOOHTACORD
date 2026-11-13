import hashlib
import unittest
from unittest.mock import patch

from .review_history import REVIEWS, verify_review


class RecoveryEvidenceTest(unittest.TestCase):
    @patch('tools.verify.livekit_network_config.review_history.evidence_content')
    def test_uses_recovery_revision_and_rejects_changed_hash(self, content):
        content.return_value = b'original\r\n'
        expected = 'sha256:' + hashlib.sha256(b'original\n').hexdigest()
        revision = REVIEWS['livekit-network-recovery-review-2026-11-09.json']
        verify_review('.', revision, {'file': expected})
        self.assertEqual(content.call_args.args[1],
                         'e565420073483c7234202817eecf362cf754e844')
        with self.assertRaises(ValueError):
            verify_review('.', revision, {'file': 'sha256:wrong'})
