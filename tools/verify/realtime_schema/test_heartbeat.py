"""Negotiated liveness frames contain no private fields or telemetry."""
import copy
import json
import unittest
from pathlib import Path

from jsonschema import Draft202012Validator, FormatChecker

ROOT = Path(__file__).resolve().parents[3]


class HeartbeatSchemaTests(unittest.TestCase):
    def test_empty_heartbeat_and_rejected_extra_fields(self):
        schema = json.loads((ROOT / 'contracts/realtime.schema.json').read_text(encoding='utf-8'))
        validator = Draft202012Validator(schema, format_checker=FormatChecker())
        event = {'event_id': '11111111-1111-4111-8111-111111111111',
                 'kind': 'connection.heartbeat', 'occurred_at': '2026-11-13T00:00:00Z',
                 'payload': {}}
        self.assertEqual([], list(validator.iter_errors(event)))
        for key in ('account_id', 'revision', 'operator'):
            bad = copy.deepcopy(event)
            bad['payload'][key] = 'private'
            self.assertTrue(list(validator.iter_errors(bad)))
        bad = copy.deepcopy(event)
        bad['telemetry'] = {'reference': 'x', 'trace_id': '1' * 32, 'span_id': '1' * 16}
        self.assertTrue(list(validator.iter_errors(bad)))


if __name__ == '__main__':
    unittest.main()
