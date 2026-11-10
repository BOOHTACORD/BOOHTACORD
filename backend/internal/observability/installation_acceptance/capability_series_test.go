//go:build installation_acceptance

package installationacceptance

import (
	"encoding/json"
	"testing"
)

func TestCapabilitySeriesRequiresAllFourClassesAndExpectedValues(t *testing.T) {
	type series struct {
		Metric map[string]string `json:"metric"`
		Value  []any             `json:"value"`
	}
	rows := []series{}
	for _, name := range []string{"voice_platform_realtime_capability_connections_active", "voice_platform_realtime_capability_connections_total"} {
		for _, class := range []string{"both", "neither", "roster_only", "maintenance_only"} {
			value := "0"
			if class == "neither" || (class == "both" && name == "voice_platform_realtime_capability_connections_total") {
				value = "1"
			}
			rows = append(rows, series{map[string]string{"__name__": name, "capability": class}, []any{1, value}})
		}
	}
	encode := func(v []series) []byte {
		raw, _ := json.Marshal(map[string]any{"data": map[string]any{"result": v}})
		return raw
	}
	if !capabilitySeriesMatch(encode(rows)) {
		t.Fatal("valid series rejected")
	}
	if capabilitySeriesMatch(encode(rows[:7])) {
		t.Fatal("missing class accepted")
	}
	rows[0].Metric["account_id"] = "secret"
	if capabilitySeriesMatch(encode(rows)) {
		t.Fatal("private label accepted")
	}
}
