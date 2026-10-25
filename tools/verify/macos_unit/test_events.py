import unittest
import re
from tools.ci.native.process import ROOT
from .events import EXPECTED, validate


def fixture():
    rows = []
    for index, name in enumerate(EXPECTED):
        rows.extend([{'type': 'testStart', 'test': {'id': index, 'name': name}},
                     {'type': 'testDone', 'testID': index, 'result': 'success', 'skipped': False}])
    return rows + [{'type': 'done', 'success': True}]


class EventTests(unittest.TestCase):
    def test_inventory_matches_every_source_declaration(self):
        source = (ROOT / 'clients/flutter/packages/livekit_client/test/options/screen_capture_engine_test.dart').read_text()
        self.assertEqual(set(EXPECTED), set(re.findall(r"\btest\('([^']+)'", source)))

    def test_every_named_platform_case_must_execute(self):
        self.assertEqual(8, validate(fixture()))

    def test_missing_skipped_failed_duplicate_or_incomplete_stream_fails(self):
        for mode in ('missing', 'skipped', 'failure', 'duplicate', 'incomplete'):
            rows = fixture()
            if mode == 'missing': del rows[:2]
            elif mode == 'skipped': rows[1]['skipped'] = True
            elif mode == 'failure': rows[1]['result'] = 'error'
            elif mode == 'duplicate': rows.insert(2, rows[1])
            else: rows.pop()
            with self.subTest(mode=mode), self.assertRaises(ValueError): validate(rows)
