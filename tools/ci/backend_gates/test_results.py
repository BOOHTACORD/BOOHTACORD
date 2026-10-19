"""Source/run-bound backend parts cannot replace any required operation."""
import copy
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
from . import results

SOURCE = 'a' * 40


def fixture():
    return ({name: {'result': 'success'} for name in results.PROFILES}, [
        {'source_revision': SOURCE, 'profile': name, 'status': 'PASS',
         'operations': list(results.OPERATIONS[name]), 'seconds': 1.0,
         'execution': results.execution()} for name in results.PROFILES])


class ResultTests(unittest.TestCase):
    def test_complete_parts_and_durations(self):
        needs, rows = fixture()
        self.assertEqual(results.validate(SOURCE, needs, rows)['status'], 'PASS')
        with tempfile.TemporaryDirectory() as name:
            for row in rows: (Path(name)/(row['profile']+'.json')).write_text(json.dumps(row))
            self.assertEqual(results.read_reports(name), rows)
            (Path(name)/'extra.json').write_text('{}')
            with self.assertRaises(ValueError): results.read_reports(name)

    def test_missing_foreign_failed_skipped_duplicate_or_partial_parts_fail(self):
        for change in ('missing', 'foreign', 'failed', 'skipped', 'duplicate', 'partial', 'attempt', 'duration'):
            needs, rows = copy.deepcopy(fixture())
            if change == 'missing': rows.pop()
            if change == 'foreign': rows[0]['source_revision'] = 'b'*40
            if change == 'failed': rows[0]['status'] = 'FAIL'
            if change == 'skipped': needs['database']['result'] = 'skipped'
            if change == 'duplicate': rows[1] = rows[0]
            if change == 'partial': rows[0]['operations'].pop()
            if change == 'attempt': rows[0]['execution']['run_attempt'] = '99'
            if change == 'duration': rows[0]['seconds'] = float('nan')
            with self.subTest(change=change), self.assertRaises(ValueError): results.validate(SOURCE, needs, rows)

    def test_hosted_attempt_required(self):
        with patch.dict(os.environ, GITHUB_ACTIONS='true', GITHUB_RUN_ID='12', GITHUB_RUN_ATTEMPT='2'):
            self.assertEqual(results.execution(), {'run_id':'12', 'run_attempt':'2'})
        with patch.dict(os.environ, GITHUB_ACTIONS='true', GITHUB_RUN_ID='', GITHUB_RUN_ATTEMPT='2'):
            with self.assertRaises(ValueError): results.execution()
