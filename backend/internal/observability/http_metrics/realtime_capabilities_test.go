package httpmetrics

import (
	"strings"
	"testing"
)

func TestCapabilityMetricsAreBalancedAndUseOnlyFixedClasses(t *testing.T) {
	r := New()
	r.RealtimeCapabilityOpened("both")
	r.RealtimeCapabilityOpened("neither")
	r.RealtimeCapabilityOpened("both")
	r.RealtimeCapabilityClosed("both")
	r.RealtimeCapabilityOpened("secret-account")
	r.RealtimeCapabilityClosed("secret-account")
	metrics := scrapeMetrics(r)
	for _, want := range []string{
		`voice_platform_realtime_capability_connections_active{capability="both"} 1`,
		`voice_platform_realtime_capability_connections_total{capability="both"} 2`,
		`voice_platform_realtime_capability_connections_active{capability="neither"} 1`,
		`voice_platform_realtime_capability_connections_total{capability="neither"} 1`,
		`voice_platform_realtime_capability_connections_active{capability="roster_only"} 0`,
		`voice_platform_realtime_capability_connections_total{capability="maintenance_only"} 0`,
	} {
		if !strings.Contains(metrics, want) {
			t.Fatalf("missing %q", want)
		}
	}
	if strings.Contains(metrics, "secret-account") {
		t.Fatal("unbounded capability label")
	}
}
