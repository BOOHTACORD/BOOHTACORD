import hashlib
import io
import json
import unittest
import zipfile

from tools.product_map.release.archive import read_native_evidence
from tools.product_map.release.test_publication import fixture


def archive(records):
    data = io.BytesIO()
    with zipfile.ZipFile(data, 'w', zipfile.ZIP_DEFLATED) as target:
        for name, content in records:
            target.writestr(name, content)
    return data.getvalue()


def metadata(data):
    return {'artifact_digest': 'sha256:' + hashlib.sha256(data).hexdigest(),
            'artifact_size': len(data), 'source_revision': 'a' * 40,
            'run_id': 123, 'run_attempt': 2, 'status': 'CANDIDATE_UNVERIFIED'}


class ArchiveTests(unittest.TestCase):
    def test_valid_archive_is_consistent_but_not_yet_authenticated(self):
        snapshot, contract, receipt = fixture()
        raw = archive([('feature-snapshot.json', json.dumps(snapshot)),
                       ('contract.json', json.dumps(contract)),
                       ('publication.json', json.dumps(receipt)),
                       ('source.json', json.dumps(contract))])
        result = read_native_evidence(raw, metadata(raw))
        self.assertEqual(result['status'], 'MATCHED_UNVERIFIED')
        self.assertEqual(result['published'], 'UNKNOWN')

    def test_rejects_missing_snapshot_foreign_path_and_digest_mismatch(self):
        snapshot, contract, receipt = fixture()
        records = [('contract.json', json.dumps(contract)),
                   ('publication.json', json.dumps(receipt)), ('source.json', '{}')]
        for rows in (records, records + [('../feature-snapshot.json', json.dumps(snapshot))]):
            raw = archive(rows)
            with self.subTest(rows=rows), self.assertRaises(ValueError):
                read_native_evidence(raw, metadata(raw))
        raw = archive(records + [('feature-snapshot.json', json.dumps(snapshot))])
        wrong = dict(metadata(raw), artifact_digest='sha256:' + '0' * 64)
        with self.assertRaises(ValueError):
            read_native_evidence(raw, wrong)

    def test_rejects_source_or_run_identity_mismatch(self):
        snapshot, contract, receipt = fixture()
        source = dict(contract, source_revision='c' * 40)
        raw = archive([('feature-snapshot.json', json.dumps(snapshot)),
                       ('contract.json', json.dumps(contract)),
                       ('publication.json', json.dumps(receipt)),
                       ('source.json', json.dumps(source))])
        with self.assertRaisesRegex(ValueError, 'source'):
            read_native_evidence(raw, metadata(raw))
        source['source_revision'] = contract['source_revision']
        raw = archive([('feature-snapshot.json', json.dumps(snapshot)),
                       ('contract.json', json.dumps(contract)),
                       ('publication.json', json.dumps(receipt)),
                       ('source.json', json.dumps(source))])
        with self.assertRaisesRegex(ValueError, 'producer'):
            read_native_evidence(raw, dict(metadata(raw), run_attempt=1))
