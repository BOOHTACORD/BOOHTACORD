package publish_screen_descriptor

import (
	"bytes"
	"encoding/json"
	"os"
	"testing"
)

func TestLegacyProfileScenarioUsesExplicitSharedFixture(t *testing.T) {
	raw, err := os.ReadFile("../../../../contracts/screen-share-profile-v1.fixtures.json")
	if err != nil {
		t.Fatal(err)
	}
	var fixture struct {
		Valid json.RawMessage `json:"validDescriptor"`
		Cases []struct {
			Name      string                     `json:"name"`
			Overrides map[string]json.RawMessage `json:"overrides"`
			Accepted  bool                       `json:"accepted"`
		} `json:"descriptorCases"`
	}
	if err := json.Unmarshal(raw, &fixture); err != nil {
		t.Fatal(err)
	}
	for _, row := range fixture.Cases {
		t.Run(row.Name, func(t *testing.T) {
			var value map[string]json.RawMessage
			if err := json.Unmarshal(fixture.Valid, &value); err != nil {
				t.Fatal(err)
			}
			for key, override := range row.Overrides {
				value[key] = override
			}
			payload, err := json.Marshal(value)
			if err != nil {
				t.Fatal(err)
			}
			var descriptor Descriptor
			// Match the existing HTTP boundary: observations and unknown fields
			// are rejected before DTO/domain validation, not silently discarded.
			decoder := json.NewDecoder(bytes.NewReader(payload))
			decoder.DisallowUnknownFields()
			err = decoder.Decode(&descriptor)
			accepted := err == nil && Validate(descriptor)
			if accepted != row.Accepted {
				t.Fatalf("accepted=%v, expected=%v", accepted, row.Accepted)
			}
		})
	}
}
