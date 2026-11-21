import json
import unittest
from pathlib import Path

from jsonschema import Draft202012Validator


class ActivityInputSchemaTests(unittest.TestCase):
    def test_only_minimal_activity_and_inactive_frames_are_allowed(self):
        root = Path(__file__).resolve().parents[3]
        schema = json.loads((root / 'contracts/realtime.schema.json').read_text(encoding='utf-8'))
        validator = Draft202012Validator(schema['$defs']['ClientActivityFrame'])
        for value in ('activity', 'inactive'):
            self.assertTrue(validator.is_valid({'type': value}))
        for frame in ({'type': 'inactive', 'timestamp': 123}, {'type': 'idle'}, {}, {'type': 'activity', 'user_id': 'other'}):
            self.assertFalse(validator.is_valid(frame))


if __name__ == '__main__':
    unittest.main()
