"""Observed CI provenance must not change the canonical three-field builder contract."""
import json
from pathlib import Path
import tempfile
import unittest
from .receipt_projection import write_receipts


class ReceiptProjectionTests(unittest.TestCase):
    def test_canonical_receipts_and_provenance_are_separate(self):
        observed=dict(head='a'*40,status='success',run=101,checks={g:dict(id=i+1,conclusion='success') for i,g in enumerate(('backend','web','contracts'))})
        with tempfile.TemporaryDirectory() as directory:
            path=Path(directory);write_receipts(path,'current','a'*40,observed)
            files=list((path/'checks-current').iterdir());self.assertEqual(3,len(files))
            for p in files:self.assertEqual({'source_revision','gate','status'},set(json.loads(p.read_text())))
            self.assertEqual(observed,json.loads((path/'observed-ci-current.json').read_text()))

    def test_wrong_source_or_unsuccessful_gate_cannot_be_projected(self):
        with tempfile.TemporaryDirectory() as directory,self.assertRaises(ValueError):
            write_receipts(Path(directory),'current','a'*40,dict(head='b'*40,status='success',checks={}))
