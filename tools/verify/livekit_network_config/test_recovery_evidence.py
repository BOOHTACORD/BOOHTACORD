import hashlib
import unittest
from unittest.mock import patch

from .recovery_evidence import verify_recovery_evidence


class RecoveryEvidenceTest(unittest.TestCase):
    @patch('tools.verify.livekit_network_config.recovery_evidence.evidence_content')
    def test_uses_recovery_revision_and_rejects_changed_hash(self, content):
        content.return_value = b'original\r\n'
        expected = 'sha256:' + hashlib.sha256(b'original\n').hexdigest()
        verify_recovery_evidence('.', {'file': expected})
        self.assertEqual(content.call_args.args[1],
                         'e565420073483c7234202817eecf362cf754e844')
        with self.assertRaises(ValueError):
            verify_recovery_evidence('.', {'file': 'sha256:wrong'})
