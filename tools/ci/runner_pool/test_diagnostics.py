"""Untrusted guest diagnostics retain numbers only and cannot delay teardown."""
import json
from pathlib import Path
import tempfile
import subprocess
import unittest
from unittest.mock import patch
from . import diagnostics


class DiagnosticsTests(unittest.TestCase):
    def test_failed_receipt_write_leaves_no_unbounded_temporary_history(self):
        with tempfile.TemporaryDirectory() as directory, \
                patch.object(diagnostics.json, 'dumps', side_effect=OSError('disk write failed')):
            diagnostics.capture('boohtacord-ci-1', lambda *a, **k: '{"oom_kill":0}', Path(directory))
            self.assertEqual([], list(Path(directory).iterdir()))

    def test_guest_text_and_unknown_fields_never_reach_host_record(self):
        calls = []
        def execute(args, **kwargs):
            calls.append((args, kwargs))
            return json.dumps({'free_bytes': 123, 'oom_kill': 2,
                               'http_errors': 3, 'message': 'private-session-secret',
                               'io_errors': 'private-session-secret', 'cpu_count': -1})
        with tempfile.TemporaryDirectory() as directory:
            diagnostics.capture('boohtacord-ci-1', execute, Path(directory))
            value = (Path(directory) / 'boohtacord-ci-1.json').read_text()
            record = json.loads(value)
        self.assertEqual(123, record['metrics']['free_bytes'])
        self.assertEqual(2, record['metrics']['oom_kill'])
        self.assertNotIn('private-session-secret', value)
        self.assertNotIn('io_errors', record['metrics'])
        self.assertNotIn('cpu_count', record['metrics'])
        self.assertIn('head -c 8193', calls[0][0][-1])
        self.assertIn('timeout 15', calls[0][0][-1])
        self.assertIn('/snap/lxd/current/bin/lxc', calls[0][0][-1])
        self.assertEqual(20, calls[0][1]['timeout'])

    def test_oversized_or_invalid_output_cannot_create_a_record(self):
        for output in ('x' * 8193, 'not-json', '[]', '{"oom_kill":true}'):
            with self.subTest(output=output[:20]), tempfile.TemporaryDirectory() as directory:
                diagnostics.capture('boohtacord-ci-1', lambda *a, **k: output, Path(directory))
                self.assertEqual([], list(Path(directory).iterdir()))

    def test_failed_observation_does_not_block_guest_cleanup(self):
        def fail(*args, **kwargs):
            raise subprocess.TimeoutExpired('read-only observation', 20)
        with tempfile.TemporaryDirectory() as directory:
            diagnostics.capture('boohtacord-ci-2', fail, Path(directory))
            self.assertEqual([], list(Path(directory).iterdir()))

    def test_controller_shutdown_is_not_swallowed(self):
        def stop(*args, **kwargs):
            raise RuntimeError('Worker shutdown')
        with tempfile.TemporaryDirectory() as directory:
            with self.assertRaisesRegex(RuntimeError, 'Worker shutdown'):
                diagnostics.capture('boohtacord-ci-1', stop, Path(directory))

    def test_only_bounded_pool_names_can_select_a_host_file(self):
        with tempfile.TemporaryDirectory() as directory:
            for guest in ('../../escape', 'boohtacord-ci-base', 'boohtacord-ci-5'):
                with self.assertRaises(ValueError):
                    diagnostics.capture(guest, lambda *a, **k: '{}', Path(directory))

    def test_latest_record_replaces_previous_one_without_growing_history(self):
        with tempfile.TemporaryDirectory() as directory:
            for value in (1, 2):
                diagnostics.capture('boohtacord-ci-2', lambda *a, **k: json.dumps({'oom_kill': value}), Path(directory))
            files = list(Path(directory).iterdir())
            self.assertEqual(1, len(files))
            self.assertEqual(2, json.loads(files[0].read_text())['metrics']['oom_kill'])
            self.assertEqual(0o600, files[0].stat().st_mode & 0o777)
