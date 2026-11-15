"""A partial retry must retain successful receipts without relabelling them."""
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
from . import aggregate
from . import results
from .profiles import OPERATIONS
from .test_results import record


class InheritedReceiptTests(unittest.TestCase):
    def test_android_retry_keeps_original_successful_profile_attempts(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary).resolve()
            directory = root / '.out/ci/flutter-parts'
            original = []
            for profile in OPERATIONS:
                attempt = '2' if profile == 'android' else '1'
                folder = directory / ('flutter-part-flutter-' + 'a' * 40 + '-123-' + attempt + '-' + profile)
                folder.mkdir(parents=True)
                row = record(profile); row['run_attempt'] = attempt
                file = folder / (profile + '.json'); file.write_text(json.dumps(row), encoding='utf-8')
                original.append((file, file.read_bytes()))
            needs = {profile: {'result': 'success'} for profile in OPERATIONS}
            with patch.object(aggregate, 'ROOT', root), \
                 patch.object(aggregate.source, 'context', return_value=('a' * 40, '123', '2', 'flutter')), \
                 patch.object(aggregate.source, 'verify'), \
                 patch.dict(os.environ, {'FLUTTER_NEEDS': json.dumps(needs)}):
                aggregate.main()
                needs['android']['result'] = 'failure'
                with patch.dict(os.environ, {'FLUTTER_NEEDS': json.dumps(needs)}), self.assertRaises(ValueError):
                    aggregate.main()
            for file, raw in original:
                self.assertEqual(file.read_bytes(), raw)

    def test_inheritance_does_not_waive_source_execution_status_or_coverage(self):
        attempts = {p: '2' if p == 'android' else '1' for p in OPERATIONS}
        needs = {p: {'result': 'success'} for p in OPERATIONS}
        for field, value in [('source_revision', 'c' * 40), ('run_id', '124'),
                             ('run_attempt', '3'), ('status', 'FAIL'), ('completed', [])]:
            parts = [record(p) for p in OPERATIONS]
            for part in parts: part['run_attempt'] = attempts[part['profile']]
            next(part for part in parts if part['profile'] == 'android')[field] = value
            with self.subTest(field=field), self.assertRaises(ValueError):
                results.validate(parts, needs, 'a' * 40, '123', '2', attempts=attempts)
