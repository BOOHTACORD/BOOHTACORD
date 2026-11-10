import copy
import tempfile
import unittest
from pathlib import Path

from tools.product_map.release.publication import load_record, match_publication


def fixture():
    sha = 'a' * 40
    digest = 'b' * 64
    execution = {'run_id': '123', 'run_attempt': '2'}
    snapshot = {'schema_version': 1, 'source_revision': sha, 'platform': 'windows',
                'version': '1.0.52+88', 'release_id': 'windows-direct-stable-r67',
                'manifest_sha256': digest, 'execution': execution,
                'build_provenance': 'VERIFIED_ASSET_CONTRACT', 'published': 'UNKNOWN',
                'runtime': 'NOT_VERIFIED'}
    contract = {'status': 'PASS', 'source_revision': sha, 'platform': 'windows',
                'repository': 'BOOHTACORD/BOOHTACORD', 'release_mode': 'stable',
                'tag_verified': True,
                'tag': 'windows-v1.0.52', 'manifest_sha256': digest,
                'identity': {'version': '1.0.52', 'native_build': '88',
                             'release_id': 'windows-direct-stable-r67'},
                'assets': {'artifact-manifest.json': {'sha256': digest}},
                'execution': execution}
    receipt = {'status': 'PASS', 'source_revision': sha, 'tag': 'windows-v1.0.52',
               'release_id': 17, 'manifest_sha256': digest, 'execution': execution}
    return snapshot, contract, receipt


class PublicationTests(unittest.TestCase):
    def test_matching_files_are_not_proof_of_published_release(self):
        result = match_publication(*fixture())
        self.assertEqual(result['status'], 'MATCHED_UNVERIFIED')
        self.assertEqual(result['published'], 'UNKNOWN')
        self.assertEqual(result['runtime'], 'NOT_VERIFIED')

    def test_every_identity_mismatch_fails_closed(self):
        for target, key, replacement in (
                (0, 'source_revision', 'c' * 40), (0, 'manifest_sha256', 'c' * 64),
                (0, 'release_id', 'foreign'), (0, 'version', '1.0.53+88'),
                (0, 'platform', 'android'), (0, 'build_provenance', 'UNVERIFIED'),
                (1, 'status', 'FAIL'), (1, 'tag', 'windows-v1.0.53'),
                (2, 'status', 'FAIL'), (2, 'release_id', True),
                (2, 'execution', {'run_id': '123', 'run_attempt': '1'})):
            values = list(fixture())
            values[target] = copy.deepcopy(values[target])
            values[target][key] = replacement
            with self.subTest(target=target, key=key), self.assertRaises(ValueError):
                match_publication(*values)

    def test_missing_record_fails_closed(self):
        snapshot, contract, receipt = fixture()
        del contract['assets']
        with self.assertRaises(ValueError):
            match_publication(snapshot, contract, receipt)

    def test_rejects_duplicate_fields_and_nonfinite_numbers(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / 'receipt.json'
            for content in ('{"status":"PASS","status":"FAIL"}', '{"x":NaN}'):
                path.write_text(content, encoding='utf-8')
                with self.subTest(content=content), self.assertRaises(ValueError):
                    load_record(path)
