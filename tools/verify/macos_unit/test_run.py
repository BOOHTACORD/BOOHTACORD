import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
from . import run
from .test_events import fixture


class RunnerTests(unittest.TestCase):
    def test_non_apple_execution_is_blocked_and_cannot_leave_success(self):
        with tempfile.TemporaryDirectory() as directory, patch.object(run, 'ROOT', Path(directory)), \
             patch.object(run.sys, 'platform', 'win32'), patch.object(run.subprocess, 'run') as call:
            with self.assertRaises(RuntimeError): run.main()
            result = json.loads((Path(directory) / '.out/checks/macos-unit/result.json').read_text())
            self.assertEqual('BLOCKED', result['status'])
            call.assert_not_called()

    def test_real_event_stream_is_required_before_success(self):
        for skipped in (False, True):
            with tempfile.TemporaryDirectory() as directory, patch.object(run, 'ROOT', Path(directory)), \
                 patch.object(run.sys, 'platform', 'darwin'), patch.object(run, 'prepare'), \
                 patch.object(run.subprocess, 'run') as call:
                def command(args, **options):
                    if args[1] == 'test':
                        rows = fixture()
                        rows[1]['skipped'] = skipped
                        options['stdout'].write(''.join(json.dumps(row) + '\n' for row in rows))
                call.side_effect = command
                if skipped:
                    with self.assertRaises(ValueError): run.main()
                else: run.main()
                result = json.loads((Path(directory) / '.out/checks/macos-unit/result.json').read_text())
                self.assertEqual('FAIL' if skipped else 'PASS', result['status'])
