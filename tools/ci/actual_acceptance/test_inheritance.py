"""Actual receipt integrity and execution identity survive selective retries."""
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
from . import fan_in
from . import test_fan_in


class InheritedActualTests(unittest.TestCase):
    def make(self, root, attempt):
        folder, report = test_fan_in.FanInTests().make(root)
        file = folder / 'result.json'
        row = json.loads(file.read_text())
        row['run_attempt'] = attempt
        row['port_namespace'] = row['port_namespace'].replace('/123/2/', '/123/' + attempt + '/')
        file.write_text(json.dumps(row), encoding='utf-8')
        return file, report

    def invoke(self, directory, runtime='success'):
        context = {'GITHUB_SHA': 'a' * 40, 'GITHUB_RUN_ID': '123', 'GITHUB_RUN_ATTEMPT': '2',
                   'RUNTIME_RESULT': runtime}
        with patch.object(fan_in, 'Path', return_value=directory), \
             patch('sys.argv', ['fan-in', '--profiles', '["sfu"]']), patch.dict(os.environ, context):
            fan_in.main()

    def test_single_flattened_archive_keeps_its_original_attempt(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary).resolve(); file, _ = self.make(root, '1'); before = file.read_bytes()
            self.invoke(root)
            self.assertEqual(file.read_bytes(), before)
            with self.assertRaises(ValueError): self.invoke(root, 'failure')

    def test_newest_archive_is_checked_without_falling_back_on_older_success(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary).resolve()
            for attempt in ('1', '2'):
                archive = root / ('actual-sfu-' + 'a' * 40 + '-123-' + attempt)
                archive.mkdir(); file, report = self.make(archive, attempt)
            self.invoke(root)
            report.write_text('{}')
            with self.assertRaises(ValueError): self.invoke(root)

    def test_flat_inherited_receipt_rejects_foreign_source_run_and_future_attempt(self):
        for field, value in [('source_revision', 'c' * 40), ('run_id', '124'), ('run_attempt', '3')]:
            with self.subTest(field=field), tempfile.TemporaryDirectory() as temporary:
                root = Path(temporary).resolve(); file, _ = self.make(root, '1')
                row = json.loads(file.read_text()); row[field] = value
                file.write_text(json.dumps(row), encoding='utf-8')
                with self.assertRaises(ValueError): self.invoke(root)

    def test_legacy_manual_flat_layout_remains_strict_to_current_attempt(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary).resolve(); file, _ = self.make(root, '2')
            fan_in.verify_downloaded(root, ['sfu'], 'a' * 40, '123', '2', None)
            row = json.loads(file.read_text()); row['run_attempt'] = '1'
            file.write_text(json.dumps(row), encoding='utf-8')
            with self.assertRaises(ValueError):
                fan_in.verify_downloaded(root, ['sfu'], 'a' * 40, '123', '2', None)
