"""Maintenance events have one bounded public payload and no private metadata."""
import copy
import json
import unittest
from pathlib import Path

from jsonschema import Draft202012Validator, FormatChecker

ROOT = Path(__file__).resolve().parents[3]
UUID = "11111111-1111-4111-8111-111111111111"


class MaintenanceSchemaTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        schema = json.loads((ROOT / "contracts/realtime.schema.json").read_text(encoding="utf-8"))
        cls.validator = Draft202012Validator(schema, format_checker=FormatChecker())

    def event(self, kind):
        return {"event_id": UUID, "occurred_at": "2026-11-08T19:00:00Z", "kind": kind,
                "payload": {"version": 1, "generation": UUID, "revision": 1, "active": False}}

    def test_snapshot_and_change_accept_only_the_public_shape(self):
        for kind in ("maintenance.snapshot", "maintenance.changed"):
            event = self.event(kind)
            self.assertEqual([], list(self.validator.iter_errors(event)))
            event["payload"]["active"] = True
            self.assertEqual([], list(self.validator.iter_errors(event)))

    def test_malformed_and_private_payloads_are_rejected(self):
        base = self.event("maintenance.snapshot")
        payloads = (
            {"version": 1, "generation": UUID, "revision": 1},
            {**base["payload"], "operator": "private"},
            {**base["payload"], "active": "false"},
            {**base["payload"], "version": 2},
            {**base["payload"], "generation": "not-a-uuid"},
            {**base["payload"], "revision": 0},
            {**base["payload"], "revision": 1.5},
            {**base["payload"], "revision": 9007199254740992},
        )
        for kind in ("maintenance.snapshot", "maintenance.changed"):
            for payload in payloads:
                event = copy.deepcopy(base)
                event["kind"] = kind
                event["payload"] = payload
                with self.subTest(kind=kind, payload=payload):
                    self.assertTrue(list(self.validator.iter_errors(event)))


if __name__ == "__main__":
    unittest.main()
