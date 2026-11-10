package skiprequests

import (
	"net/http/httptest"
	"testing"
)

func TestOnlyFixedServiceRoutesAreSkipped(t *testing.T) {
	for _, path := range []string{
		"/metrics", "/api/v1/health", "/api/v1/maintenance",
		"/api/v1/auth/session", "/api/v1/telemetry/traces",
		"/api/v1/voice/screen-metrics",
		"/internal/media-admission", "/internal/livekit/roster",
	} {
		if !Skip(httptest.NewRequest("GET", path, nil)) {
			t.Errorf("service path %q was recorded", path)
		}
	}
	for _, path := range []string{
		"/api/v1/realtime", "/api/v1/channels/id/messages",
		"/api/v1/voice/channels/id/leases", "/api/v1/telemetry/traces/extra",
		"/api/v1/maintenance/events", "/api/v1/voice/rosters/events",
	} {
		if Skip(httptest.NewRequest("GET", path, nil)) {
			t.Errorf("application path %q was skipped", path)
		}
	}
}
