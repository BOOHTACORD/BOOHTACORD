package centralprojection

import (
	common "go.opentelemetry.io/proto/otlp/common/v1"
	"testing"
	identity "voice-platform/backend/internal/observability/installation"
)

func TestRetiredStreamsAreNotCentralOperations(t *testing.T) {
	for _, name := range []string{"GET /api/v1/maintenance/events", "GET /api/v1/voice/rosters/events"} {
		if OperationNames[name] {
			t.Fatalf("retired operation remains allowed: %s", name)
		}
	}
	for _, name := range []string{"GET /api/v1/maintenance", "POST /api/v1/voice/channels/{channelID}/leases", "voice.sfu_revocation.dispatch"} {
		if !OperationNames[name] {
			t.Fatalf("retained operation missing: %s", name)
		}
	}
}

func TestRetiredStreamMetricLabelsAreNotProjected(t *testing.T) {
	i, _ := identity.New()
	for _, operation := range []string{"maintenance_events", "roster_events"} {
		for _, label := range MetricLabels([]*common.KeyValue{String("operation", operation)}, i, "boohtacord-api", "") {
			if label.Key == "operation" {
				t.Fatalf("retired operation label projected: %s", operation)
			}
		}
	}
}
