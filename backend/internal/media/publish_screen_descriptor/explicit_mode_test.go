package publish_screen_descriptor

import (
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
			err = json.Unmarshal(payload, &descriptor)
			// Extra fields are rejected by the HTTP shape boundary, not this DTO.
			if row.Name == "observation-cannot-masquerade-as-descriptor" {
				t.Skip("unknown fields are covered by the HTTP shape tests")
			}
			accepted := err == nil && Validate(descriptor)
			if accepted != row.Accepted {
				t.Fatalf("accepted=%v, expected=%v", accepted, row.Accepted)
			}
		})
	}
}
