"""Voice roster snapshots are strict, metadata-limited and versioned."""
import copy
import json
import unittest
from pathlib import Path
from jsonschema import Draft202012Validator, FormatChecker

ROOT = Path(__file__).resolve().parents[3]
ID = '11111111-1111-4111-8111-111111111111'
TIME = '2026-11-09T00:00:00Z'


class RosterSchemaTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        schema = json.loads((ROOT/'contracts/realtime.schema.json').read_text(encoding='utf-8'))
        cls.validator = Draft202012Validator(schema, format_checker=FormatChecker())

    def event(self):
        return {'event_id': ID, 'kind': 'voice.roster.snapshot', 'occurred_at': TIME,
                'payload': {'version': 1, 'generation': ID, 'revision': 1, 'observed_at': TIME,
                            'channels': [{'channel_id': ID, 'participants': []}]}}

    def test_empty_and_populated_snapshots(self):
        event = self.event()
        self.assertEqual([], list(self.validator.iter_errors(event)))
        empty = copy.deepcopy(event); empty['payload']['channels'] = []
        self.assertEqual([], list(self.validator.iter_errors(empty)))
        event['payload']['channels'][0]['participants'].append({
            'account_id': ID, 'display_name': 'Участник', 'screen_sharing': True, 'microphone_muted': False})
        self.assertEqual([], list(self.validator.iter_errors(event)))

    def test_rejects_malformed_and_unscoped_fields(self):
        base = self.event()
        payloads = [
            {**base['payload'], 'generation': 'bad'},
            {**base['payload'], 'revision': 0},
            {**base['payload'], 'revision': 9007199254740992},
            {**base['payload'], 'observed_at': 'invalid'},
            {**base['payload'], 'private_token': 'secret'},
            {**base['payload'], 'channels': [{'channel_id': ID, 'participants': [], 'extra': True}]},
            {**base['payload'], 'channels': [{'channel_id': ID, 'participants': [{'account_id': ID, 'display_name': 'A', 'screen_sharing': False}]}]},
        ]
        for payload in payloads:
            event = copy.deepcopy(base); event['payload'] = payload
            with self.subTest(payload=payload):
                self.assertTrue(list(self.validator.iter_errors(event)))

    def test_unavailable_has_only_safe_fixed_code(self):
        event = {'event_id': ID, 'kind': 'voice.roster.unavailable', 'occurred_at': TIME,
                 'payload': {'version': 1, 'code': 'temporarily_unavailable'}}
        self.assertEqual([], list(self.validator.iter_errors(event)))
        for payload in ({'version': 1, 'code': 'database timeout'},
                        {'version': 1, 'code': 'temporarily_unavailable', 'detail': 'private'},
                        {'version': 1, 'code': 'temporarily_unavailable', 'channels': []}):
            event['payload'] = payload
            with self.subTest(payload=payload):
                self.assertTrue(list(self.validator.iter_errors(event)))


if __name__ == '__main__':
    unittest.main()
