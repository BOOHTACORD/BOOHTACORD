//go:build installation_acceptance

package installationacceptance

import (
	"encoding/json"
	"io"
	"net/http"
	"net/url"
	"os"
	"testing"

	metrics "voice-platform/backend/internal/observability/http_metrics"
)

func publishCapabilityMetrics() {
	r := metrics.New()
	r.RealtimeCapabilityOpened("both")
	r.RealtimeCapabilityOpened("neither")
	r.RealtimeCapabilityClosed("both")
}

func capabilitySeriesMatch(raw []byte) bool {
	var result struct {
		Data struct {
			Result []struct {
				Metric map[string]string `json:"metric"`
				Value  []json.RawMessage `json:"value"`
			} `json:"result"`
		} `json:"data"`
	}
	if json.Unmarshal(raw, &result) != nil {
		return false
	}
	got := map[string]map[string]string{}
	for _, series := range result.Data.Result {
		name, capability := series.Metric["__name__"], series.Metric["capability"]
		if capability != "both" && capability != "neither" && capability != "roster_only" && capability != "maintenance_only" {
			return false
		}
		for key := range series.Metric {
			if key == "account_id" || key == "session_id" || key == "user_id" {
				return false
			}
		}
		if len(series.Value) != 2 {
			return false
		}
		var value string
		if json.Unmarshal(series.Value[1], &value) != nil {
			return false
		}
		if got[name] == nil {
			got[name] = map[string]string{}
		}
		got[name][capability] = value
	}
	active := got["voice_platform_realtime_capability_connections_active"]
	total := got["voice_platform_realtime_capability_connections_total"]
	return len(active) == 4 && len(total) == 4 && active["both"] == "0" && active["neither"] == "1" && total["both"] == "1" && total["neither"] == "1"
}

func assertCapabilityMetrics(t *testing.T, installation string) {
	t.Helper()
	query := `{__name__=~"voice_platform_realtime_capability_connections_.*",installation_id="` + installation + `"}`
	eventually(t, "capability metrics in real Prometheus", func() bool {
		response, err := http.Get(os.Getenv("BOOHTACORD_TELEMETRY_TEST_PROMETHEUS") + "/api/v1/query?query=" + url.QueryEscape(query))
		if err != nil {
			return false
		}
		defer response.Body.Close()
		raw, err := io.ReadAll(io.LimitReader(response.Body, 2<<20))
		return err == nil && capabilitySeriesMatch(raw)
	})
}
