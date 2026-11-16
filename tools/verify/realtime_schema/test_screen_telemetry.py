import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]


class ScreenTelemetrySchemaTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.schema = json.loads((ROOT / "contracts/realtime.schema.json").read_text(encoding="utf-8"))
        cls.openapi = json.loads((ROOT / "contracts/openapi.yaml").read_text(encoding="utf-8"))

    def test_event_is_versioned_ephemeral_payload_with_server_freshness(self):
        self.assertIn("screen_telemetry.updated", self.schema["properties"]["kind"]["enum"])
        event = next(item for item in self.schema["allOf"]
                     if item.get("if", {}).get("properties", {}).get("kind", {}).get("const") == "screen_telemetry.updated")
        self.assertEqual(event["then"]["properties"]["payload"]["$ref"], "#/$defs/ScreenTelemetryEventV1")
        payload = self.schema["$defs"]["ScreenTelemetryEventV1"]
        self.assertFalse(payload["additionalProperties"])
        self.assertEqual(payload["required"], ["owner_lease_id", "server_received_at", "envelope"])
        self.assertNotIn("track_sid", payload["properties"])

    def test_envelope_provenance_and_availability_are_contract_bound(self):
        envelope = self.schema["$defs"]["ScreenTelemetryEnvelopeV1"]
        self.assertEqual(envelope["properties"]["schema_version"]["const"], 1)
        self.assertFalse(envelope["additionalProperties"])
        self.assertEqual(envelope["properties"]["sender_sample_age_ms"]["maximum"], 60000)
        metric = self.schema["$defs"]["ScreenTelemetryField"]
        self.assertIn("configured_only", metric["properties"]["availability"]["enum"])
        self.assertIn("not_exposed", metric["properties"]["availability"]["enum"])
        self.assertIn("permission_denied", metric["properties"]["availability"]["enum"])
        self.assertIn("sender_measured", metric["properties"]["provenance"]["enum"])
        self.assertGreaterEqual(len(metric["allOf"]), 3)

    def test_openapi_publisher_route_is_authenticated_bounded_and_transient(self):
        route = self.openapi["paths"]["/api/v1/voice/leases/{ownerLeaseID}/screen-telemetry"]["post"]
        self.assertEqual(route["operationId"], "publishScreenTelemetryV1")
        self.assertEqual(route["requestBody"]["content"]["application/json"]["schema"]["$ref"],
                         "#/components/schemas/ScreenTelemetryEnvelopeV1")
        self.assertIn("SessionCookie", route["security"][0])
        self.assertIn("never journals or stores telemetry values", route["description"])
        self.assertIn("409", route["responses"])
        self.assertIn("429", route["responses"])


if __name__ == "__main__":
    unittest.main()
