"""Installer failure responses expose only finite phase labels."""
import json
import os
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

from . import diagnostics, run


class InstallerDiagnosticTests(unittest.TestCase):
    def test_failure_receipt_contains_only_a_known_phase_and_private_permissions(self):
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / 'failure.json'
            value = diagnostics.FailureReceipt(path)
            value.mark('bundle_verification')
            self.assertTrue(value.write())
            self.assertEqual(diagnostics.failure_response('bundle_verification'), diagnostics.read_response(path))
            self.assertEqual(0o600, path.stat().st_mode & 0o777)
            self.assertNotIn('private-canary', path.read_text())

    def test_response_parser_rejects_unbounded_or_unrecognized_failure_details(self):
        invalid = [
            b'{}',
            b'{"schema_version":1,"kind":"install-result","status":"FAIL","phase":"private-canary"}',
            b'{"schema_version":1,"kind":"install-result","status":"PASS","phase":"deployment"}',
            b'{"schema_version":1,"schema_version":1,"kind":"install-result","status":"PASS"}',
            b'{"schema_version":1,"kind":"install-result","status":"FAIL","phase":[]}',
            b'x' * 2049,
        ]
        for raw in invalid:
            with self.subTest(raw=raw[:40]), self.assertRaises(ValueError):
                diagnostics.validate_response(raw)

    def test_missing_or_malformed_private_receipt_publishes_only_unknown_phase(self):
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / 'failure.json'
            path.write_text('{"private":"private-canary"}')
            self.assertEqual(diagnostics.failure_response('diagnostic_unavailable'), diagnostics.publish_response(path))
            self.assertNotIn('private-canary', json.dumps(diagnostics.publish_response(path)))
            path.write_bytes(b'\xff')
            self.assertEqual(diagnostics.failure_response('diagnostic_unavailable'), diagnostics.publish_response(path))

    def test_run_main_records_the_failed_validation_phase_without_the_exception_text(self):
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / 'failure.json'
            with patch.object(sys, 'argv', [
                'run.py', '--failure-receipt', str(path), '/fixture/bundle', 'private-canary', 'a' * 64,
            ]), self.assertRaises(ValueError):
                run.main()
            value = diagnostics.read_response(path)
            self.assertEqual('argument_validation', value['phase'])
            self.assertNotIn('private-canary', json.dumps(value))


if __name__ == '__main__':
    unittest.main()
