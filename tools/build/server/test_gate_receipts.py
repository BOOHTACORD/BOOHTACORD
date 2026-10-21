"""A signed server build requires exactly three direct unambiguous gate receipts."""
import json
import tempfile
import unittest
from pathlib import Path
from .run import gate_receipts
from .gate_receipts import collect

SOURCE = 'a' * 40
GATES = ('backend', 'web', 'contracts')


class GateReceiptTests(unittest.TestCase):
    def fixture(self, root):
        for gate in GATES:
            (root / (gate + '.json')).write_text(json.dumps({
                'source_revision': SOURCE, 'gate': gate, 'status': 'PASS'}))

    def artifacts(self, root, *, run_id='123', attempts=(1,)):
        for gate in GATES:
            for attempt in attempts:
                artifact = root / f'check-{gate}-{SOURCE}-{run_id}-{attempt}'
                artifact.mkdir(parents=True, exist_ok=True)
                (artifact / (gate + '.json')).write_text(json.dumps({
                    'source_revision': SOURCE, 'gate': gate, 'status': 'PASS'}))

    def test_collection_uses_latest_available_attempt_for_the_exact_source_and_run(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp); downloaded = root / 'artifacts'; downloaded.mkdir()
            self.artifacts(downloaded, attempts=(1, 2))
            destination = root / 'checks'
            self.assertEqual(dict.fromkeys(GATES, 'PASS'), collect(downloaded, destination, SOURCE, '123', 2))
            self.assertEqual({gate + '.json' for gate in GATES}, {path.name for path in destination.iterdir()})

    def test_bundle_retry_can_reuse_passed_gates_from_the_prior_attempt_of_the_same_run(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp); downloaded = root / 'artifacts'; downloaded.mkdir()
            self.artifacts(downloaded, attempts=(1,))
            self.assertEqual(dict.fromkeys(GATES, 'PASS'),
                             collect(downloaded, root / 'checks', SOURCE, '123', 2))

    def test_collection_rejects_wrong_source_run_and_future_attempt_artifacts(self):
        for artifact_name in (f'check-backend-{"b" * 40}-123-1',
                              f'check-backend-{SOURCE}-999-1',
                              f'check-backend-{SOURCE}-123-3'):
            with self.subTest(artifact=artifact_name), tempfile.TemporaryDirectory() as tmp:
                root = Path(tmp); downloaded = root / 'artifacts'; downloaded.mkdir()
                self.artifacts(downloaded)
                (downloaded / f'check-backend-{SOURCE}-123-1').rename(downloaded / artifact_name)
                with self.assertRaises(ValueError): collect(downloaded, root / 'checks', SOURCE, '123', 2)

    def test_collection_rejects_invalid_latest_receipt_without_falling_back(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp); downloaded = root / 'artifacts'; downloaded.mkdir()
            self.artifacts(downloaded, attempts=(1, 2))
            latest = downloaded / f'check-backend-{SOURCE}-123-2' / 'backend.json'
            latest.write_text(json.dumps({'source_revision': SOURCE, 'gate': 'backend', 'status': 'FAIL'}))
            with self.assertRaises(ValueError): collect(downloaded, root / 'checks', SOURCE, '123', 2)

    def test_collection_rejects_extra_files_and_preexisting_destination(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp); downloaded = root / 'artifacts'; downloaded.mkdir(); self.artifacts(downloaded)
            (downloaded / f'check-backend-{SOURCE}-123-1' / 'extra.json').write_text('{}')
            with self.assertRaises(ValueError): collect(downloaded, root / 'checks', SOURCE, '123', 1)
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp); downloaded = root / 'artifacts'; downloaded.mkdir(); self.artifacts(downloaded)
            destination = root / 'checks'; destination.mkdir()
            with self.assertRaises(ValueError): collect(downloaded, destination, SOURCE, '123', 1)

    def test_three_original_flat_receipts_keep_the_existing_result_contract(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp); self.fixture(root)
            self.assertEqual(dict.fromkeys(GATES, 'PASS'), gate_receipts(root, SOURCE))

    def test_missing_receipt_never_reuses_another_gate(self):
        for gate in GATES:
            with self.subTest(gate=gate), tempfile.TemporaryDirectory() as tmp:
                root = Path(tmp); self.fixture(root); (root / (gate + '.json')).unlink()
                with self.assertRaises(ValueError): gate_receipts(root, SOURCE)

    def test_failed_foreign_source_wrong_gate_or_unproven_status_is_rejected(self):
        for field, value in [('source_revision', 'b' * 40), ('gate', 'web'),
                             ('status', 'FAIL'), ('status', 'NOT_RUN'), ('status', True)]:
            with self.subTest(field=field, value=value), tempfile.TemporaryDirectory() as tmp:
                root = Path(tmp); self.fixture(root); path = root / 'backend.json'
                receipt = json.loads(path.read_text()); receipt[field] = value; path.write_text(json.dumps(receipt))
                with self.assertRaises(ValueError): gate_receipts(root, SOURCE)

    def test_duplicate_json_fields_cannot_overwrite_failed_or_foreign_values(self):
        for first, last in [('"status":"FAIL"', '"status":"PASS"'),
                            ('"gate":"web"', '"gate":"backend"'),
                            ('"source_revision":"' + 'b' * 40 + '"', '"source_revision":"' + SOURCE + '"')]:
            with tempfile.TemporaryDirectory() as tmp:
                root = Path(tmp); self.fixture(root)
                base = (root / 'backend.json').read_text()
                (root / 'backend.json').write_text('{' + first + ',' + last + ',' + base[1:])
                with self.assertRaises(ValueError): gate_receipts(root, SOURCE)

    def test_extra_duplicate_receipt_file_or_directory_cannot_be_ignored(self):
        for extra in ('backend-copy.json', 'foreign.json', 'nested'):
            with self.subTest(extra=extra), tempfile.TemporaryDirectory() as tmp:
                root = Path(tmp); self.fixture(root)
                if extra == 'nested': (root / extra).mkdir()
                else: (root / extra).write_bytes((root / 'backend.json').read_bytes())
                with self.assertRaises(ValueError): gate_receipts(root, SOURCE)

    def test_linked_receipt_is_not_direct_execution_evidence(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp); self.fixture(root); target = root / 'backend.json'; content = target.read_bytes()
            target.unlink()
            with tempfile.TemporaryDirectory() as other:
                external = Path(other) / 'receipt.json'; external.write_bytes(content); target.symlink_to(external)
                with self.assertRaises(ValueError): gate_receipts(root, SOURCE)

    def test_empty_oversized_or_invalid_json_is_rejected_without_content_in_error(self):
        for content in ('', 'private-message-canary', '{', '{"private-message-canary":"' + 'x' * 4096 + '"}'):
            with tempfile.TemporaryDirectory() as tmp:
                root = Path(tmp); self.fixture(root); (root / 'backend.json').write_text(content)
                with self.assertRaises(ValueError) as error: gate_receipts(root, SOURCE)
                self.assertNotIn('private-message-canary', str(error.exception))

    def test_unexpected_fields_and_non_objects_are_not_original_receipts(self):
        for value in ([], None, {'source_revision': SOURCE, 'gate': 'backend', 'status': 'PASS', 'extra': 'private-canary'}):
            with tempfile.TemporaryDirectory() as tmp:
                root = Path(tmp); self.fixture(root); (root / 'backend.json').write_text(json.dumps(value))
                with self.assertRaises(ValueError): gate_receipts(root, SOURCE)

    def test_request_requires_full_source_sha(self):
        for source in ('a' * 7, 'master', '', None):
            with tempfile.TemporaryDirectory() as tmp:
                root = Path(tmp); self.fixture(root)
                with self.assertRaises(ValueError): gate_receipts(root, source)
