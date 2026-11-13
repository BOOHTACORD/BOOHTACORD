import unittest
from unittest.mock import patch

from tools.product_map.release_verification.live import verify_release
from tools.product_map.release_verification.test_match import fixture


class LiveReleaseTests(unittest.TestCase):
    @patch('tools.product_map.release_verification.live.read_api')
    def test_uses_release_id_and_peels_annotated_tag(self, read):
        evidence, release, sha = fixture()
        read.side_effect = [release,
            {'ref': 'refs/tags/windows-v1.0.52', 'object': {'type': 'tag', 'sha': 'b' * 40}},
            {'object': {'type': 'commit', 'sha': sha}}]
        result = verify_release(evidence, 'windows-v1.0.52', None)
        self.assertEqual(result['published'], 'UNKNOWN')
        self.assertEqual(read.call_args_list[0].args[0], '/releases/17')
        self.assertEqual(read.call_args_list[2].args[0], '/git/tags/' + 'b' * 40)

    @patch('tools.product_map.release_verification.live.read_api')
    def test_rejects_foreign_ref_and_noncommit_object(self, read):
        evidence, release, sha = fixture()
        for ref, kind in [('refs/tags/other', 'commit'), ('refs/tags/windows-v1.0.52', 'tree')]:
            read.side_effect = [release, {'ref': ref, 'object': {'type': kind, 'sha': sha}}]
            with self.subTest(ref=ref, kind=kind), self.assertRaises(ValueError):
                verify_release(evidence, 'windows-v1.0.52', None)

    def test_rejects_untrusted_tag_before_network(self):
        evidence, _, _ = fixture()
        with self.assertRaises(ValueError):
            verify_release(evidence, '../../evil', None)
