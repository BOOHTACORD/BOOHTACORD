package centralprojection

import (
	common "go.opentelemetry.io/proto/otlp/common/v1"
	"testing"
	identity "voice-platform/backend/internal/observability/installation"
)

func TestCapabilityMetricsProjectOnlyFixedClasses(t *testing.T) {
	for _, name := range []string{"voice_platform_realtime_capability_connections_active", "voice_platform_realtime_capability_connections_total"} {
		if !MetricNames[name] {
			t.Errorf("missing %s", name)
		}
	}
	i, _ := identity.New()
	for _, value := range []string{"both", "neither", "roster_only", "maintenance_only", "private-account"} {
		labels := MetricLabels([]*common.KeyValue{String("capability", value)}, i, "boohtacord-api", "")
		found := false
		for _, label := range labels {
			if label.Key == "capability" {
				found = true
			}
		}
		if found != (value != "private-account") {
			t.Errorf("capability %q projected=%v", value, found)
		}
	}
}
