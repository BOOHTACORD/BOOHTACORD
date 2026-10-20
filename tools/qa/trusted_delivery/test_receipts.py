"""QA provenance stays outside the strict three-field shipping gate receipts."""
from copy import deepcopy
from pathlib import Path
import tempfile
import unittest
from tools.build.server.gate_receipts import read
from .receipts import write

SHA = 'a'*40


def proof():
    return {'head': SHA, 'run': 123, 'status': 'success',
            'producer_workflow': '.github/workflows/build-server.yaml',
            'checks': {gate: {'id': index, 'conclusion': 'success'}
                       for index, gate in enumerate(('backend', 'web', 'contracts'), 1)}}


class QAGateReceiptsTests(unittest.TestCase):
    def test_actual_proof_is_projected_to_the_unmodified_strict_builder_contract(self):
        observed = proof()
        original = deepcopy(observed)
        with tempfile.TemporaryDirectory() as tmp:
            target = Path(tmp)/'checks'
            write(target, SHA, observed)
            self.assertEqual(dict.fromkeys(('backend', 'web', 'contracts'), 'PASS'), read(target, SHA))
            self.assertEqual(3, len(list(target.iterdir())))
            self.assertNotIn('observed_ci', ''.join(p.read_text() for p in target.iterdir()))
        self.assertEqual(original, observed)

    def test_unproven_or_mismatched_source_never_creates_receipts(self):
        for change in ('head', 'failed', 'run', 'duplicate', 'workflow'):
            observed = proof()
            if change == 'head': observed['head'] = 'b'*40
            if change == 'failed': observed['checks']['web']['conclusion'] = 'failure'
            if change == 'run': observed['run'] = True
            if change == 'duplicate': observed['checks']['web']['id'] = 1
            if change == 'workflow': observed['producer_workflow'] = '.github/workflows/ci.yaml'
            with self.subTest(change=change), tempfile.TemporaryDirectory() as tmp:
                target = Path(tmp)/'checks'
                with self.assertRaises(ValueError): write(target, SHA, observed)
                self.assertFalse(target.exists())
