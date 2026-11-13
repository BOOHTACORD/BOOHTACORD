import json
import unittest
from unittest.mock import patch

from tools.product_map.evidence_download.run import inspect_native_run
from tools.product_map.release.test_archive import archive, metadata
from tools.product_map.release.test_publication import fixture


class NativeEvidenceTests(unittest.TestCase):
    @patch('tools.product_map.evidence_download.run.download_artifact')
    @patch('tools.product_map.evidence_download.run.fetch_candidate')
    def test_pipeline_checks_actual_archive_but_does_not_assert_publication(self, fetch, download):
        snapshot, contract, receipt = fixture()
        raw = archive([('feature-snapshot.json', json.dumps(snapshot)),
                       ('contract.json', json.dumps(contract)),
                       ('publication.json', json.dumps(receipt)),
                       ('source.json', json.dumps(contract))])
        fetch.return_value, download.return_value = metadata(raw), raw
        result = inspect_native_run('windows', 123, 'windows-v1.0.52', 'ghs_dummy')
        self.assertEqual(result['status'], 'MATCHED_UNVERIFIED')
        self.assertEqual(result['published'], 'UNKNOWN')
        fetch.assert_called_once_with('windows', 123, 'windows-v1.0.52', 'ghs_dummy')
        download.assert_called_once_with(fetch.return_value, 'ghs_dummy')

    @patch('tools.product_map.evidence_download.run.download_artifact')
    @patch('tools.product_map.evidence_download.run.fetch_candidate')
    def test_missing_snapshot_cannot_prove_release(self, fetch, download):
        raw = archive([('source.json', '{}')])
        fetch.return_value, download.return_value = metadata(raw), raw
        with self.assertRaisesRegex(ValueError, 'contents'):
            inspect_native_run('windows', 123, 'windows-v1.0.52', None)
