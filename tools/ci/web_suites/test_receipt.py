"""A Web fan-in keeps the existing release contract and never leaves stale PASS."""
import json
import os
from pathlib import Path
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch
from tools.ci.receipts import run as receipts
from .test_fan_in import SOURCE, fixture


class ReceiptTests(unittest.TestCase):
    def test_complete_parts_emit_only_the_original_three_receipt_fields(self):
        with tempfile.TemporaryDirectory() as name:
            root = Path(name); parts = root / 'parts'; parts.mkdir()
            needs, rows = fixture()
            for row in rows: (parts / (row['profile'] + '.json')).write_text(json.dumps(row))
            with patch.object(receipts, 'ROOT', root), patch.object(receipts, 'output', return_value=SOURCE), \
                 patch.object(receipts.subprocess, 'run', return_value=SimpleNamespace(returncode=0)) as run, \
                 patch('sys.argv', ['receipts', 'web', '--parts', str(parts)]), \
                 patch.dict(os.environ, GITHUB_SHA=SOURCE, WEB_NEEDS=json.dumps(needs)), \
                 self.assertRaises(SystemExit) as status:
                receipts.main()
            self.assertEqual(status.exception.code, 0)
            self.assertEqual(json.loads((root / '.out/checks/web.json').read_text()),
                             {'source_revision': SOURCE, 'gate': 'web', 'status': 'PASS'})
            self.assertEqual(run.call_count, 1, 'fan-in must not re-run the native Web suite')

    def test_partial_parts_replace_stale_success_with_fail(self):
        with tempfile.TemporaryDirectory() as name:
            root = Path(name); parts = root / 'parts'; parts.mkdir()
            target = root / '.out/checks/web.json'; target.parent.mkdir(parents=True)
            target.write_text(json.dumps({'source_revision': SOURCE, 'gate': 'web', 'status': 'PASS'}))
            needs, rows = fixture()
            for row in rows[:-1]: (parts / (row['profile'] + '.json')).write_text(json.dumps(row))
            with patch.object(receipts, 'ROOT', root), patch.object(receipts, 'output', return_value=SOURCE), \
                 patch.object(receipts.subprocess, 'run', return_value=SimpleNamespace(returncode=0)), \
                 patch('sys.argv', ['receipts', 'web', '--parts', str(parts)]), \
                 patch.dict(os.environ, GITHUB_SHA=SOURCE, WEB_NEEDS=json.dumps(needs)), \
                 self.assertRaises(ValueError):
                receipts.main()
            self.assertEqual(json.loads(target.read_text())['status'], 'FAIL')
