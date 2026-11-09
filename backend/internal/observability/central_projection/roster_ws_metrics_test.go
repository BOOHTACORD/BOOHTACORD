package centralprojection

import (
	common "go.opentelemetry.io/proto/otlp/common/v1"
	"testing"
	identity "voice-platform/backend/internal/observability/installation"
)

func TestRosterWSMetricsAndBoundedOutcomesAreProjected(t *testing.T) {
	for _, name := range []string{"voice_platform_voice_roster_ws_subscribers", "voice_platform_voice_roster_ws_initial_total", "voice_platform_voice_roster_ws_delivery_total", "voice_platform_voice_roster_ws_delivery_seconds", "voice_platform_voice_roster_ws_refresh_total", "voice_platform_voice_roster_ws_last_success_timestamp_seconds", "voice_platform_voice_roster_ws_observation_enabled"} {
		if !MetricNames[name] {
			t.Errorf("missing metric %s", name)
		}
	}
	i, _ := identity.New()
	for _, value := range []string{"success", "failure", "unavailable", "private-identifier"} {
		labels := MetricLabels([]*common.KeyValue{String("outcome", value)}, i, "boohtacord-api", "")
		found := false
		for _, label := range labels {
			if label.Key == "outcome" {
				found = true
			}
		}
		if found != (value != "private-identifier") {
			t.Errorf("outcome %q projected=%v", value, found)
		}
	}
}
