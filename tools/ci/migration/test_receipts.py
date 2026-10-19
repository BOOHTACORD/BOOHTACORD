import hashlib
import json
import unittest
from unittest.mock import patch
from . import readiness


class ReceiptTests(unittest.TestCase):
    def row(self):return dict(schema_version=1,criterion='server-release',status='PASS',source_revision='a'*40,
        scope='actual',executed=True,actual_runtime=True,mocks=False,bundle_signature_verified=True,full_smoke_verified=True,image_source_verified=True,evidence=[{'path':'evidence/raw.json','sha256':hashlib.sha256(b'raw').hexdigest()}])

    def test_tracked_matching_actual_receipt_hashes(self):
        raw=json.dumps(self.row()).encode()
        with patch.object(readiness,'tracked',side_effect=[raw,b'raw']):
            self.assertIsInstance(readiness.verify_receipt('evidence/receipt.json','a'*40),readiness.VerifiedReceipt)

    def test_wrong_source_mock_focused_or_tampered_raw_evidence_cannot_pass(self):
        for key,value in [('source_revision','b'*40),('scope','focused'),('mocks',True),('actual_runtime',False),('status','NOT_RUN')]:
            row=self.row();row[key]=value
            with self.subTest(key=key),patch.object(readiness,'tracked',return_value=json.dumps(row).encode()),self.assertRaises(ValueError):
                readiness.verify_receipt('evidence/receipt.json','a'*40)
        with patch.object(readiness,'tracked',side_effect=[json.dumps(self.row()).encode(),b'tamper']),self.assertRaises(ValueError):
            readiness.verify_receipt('evidence/receipt.json','a'*40)
