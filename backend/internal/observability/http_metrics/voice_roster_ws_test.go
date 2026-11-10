package httpmetrics

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"
)

func TestRecorderExposesWSRosterLifecycle(t *testing.T) {
	recorder := New()
	recorder.RosterWSOpened()
	recorder.ObserveRosterWSDelivery(time.Millisecond, "success", true)
	recorder.ObserveRosterWSRefresh(true)
	response := httptest.NewRecorder()
	recorder.Handler().ServeHTTP(response, httptest.NewRequest(http.MethodGet, "/metrics", nil))
	for _, name := range []string{"voice_platform_voice_roster_ws_subscribers 1", `voice_platform_voice_roster_ws_initial_total{outcome="success"} 1`, `voice_platform_voice_roster_ws_refresh_total{outcome="success"} 1`} {
		if !strings.Contains(response.Body.String(), name) {
			t.Fatalf("missing %s", name)
		}
	}
	recorder.RosterWSClosed()
}

func TestRetiredSSERosterMetricsAreNotRegistered(t *testing.T) {
	recorder := New()
	response := httptest.NewRecorder()
	recorder.Handler().ServeHTTP(response, httptest.NewRequest(http.MethodGet, "/metrics", nil))
	for _, name := range []string{"voice_platform_voice_roster_streams_active", "voice_platform_voice_roster_stream_ends_total", "voice_platform_voice_roster_initial_total", "voice_platform_voice_roster_initial_seconds", "voice_platform_voice_roster_last_success_timestamp_seconds", "voice_platform_voice_roster_observation_enabled"} {
		if strings.Contains(response.Body.String(), name) {
			t.Fatalf("retired SSE instrument still registered: %s", name)
		}
	}
}
