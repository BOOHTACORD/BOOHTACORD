package centralprojection

import (
	"testing"

	common "go.opentelemetry.io/proto/otlp/common/v1"
	identity "voice-platform/backend/internal/observability/installation"
)

func TestRealtimeAndMaintenanceMetricsKeepOnlyFixedDimensions(t *testing.T) {
	for _, name := range []string{"voice_platform_realtime_connections_active", "voice_platform_maintenance_observer_reads_total"} {
		if !MetricNames[name] {
			t.Fatalf("metric not projected: %s", name)
		}
	}
	i, _ := identity.New()
	for _, scope := range []string{"public", "authenticated", "private-account"} {
		labels := MetricLabels([]*common.KeyValue{String("scope", scope)}, i, "boohtacord-api", "")
		found := false
		for _, label := range labels {
			if label.Key == "scope" {
				found = true
			}
		}
		if found != (scope != "private-account") {
			t.Fatalf("scope projection: %s", scope)
		}
	}
}
