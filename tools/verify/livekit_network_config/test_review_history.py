import hashlib
import unittest
from unittest.mock import patch

from .review_history import verify_review


class ReviewHistoryTest(unittest.TestCase):
    @patch('tools.verify.livekit_network_config.review_history.evidence_content')
    def test_verifies_each_snapshot_and_rejects_corruption(self, content):
        content.return_value = b'original\r\n'
        digest = 'sha256:' + hashlib.sha256(b'original\n').hexdigest()
        revision = 'a' * 40
        verify_review('.', revision, {'file': digest})
        self.assertEqual(content.call_args.args[1], revision)
        with self.assertRaises(ValueError):
            verify_review('.', revision, {'file': 'sha256:wrong'})
