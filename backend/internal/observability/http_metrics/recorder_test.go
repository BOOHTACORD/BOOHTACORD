package httpmetrics

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"
)

func TestRecorderPublishesClientUpdateHealthWithoutReleaseIdentity(t *testing.T) {
	recorder := New()
	recorder.ObserveClientUpdateCheck("web", "published")
	recorder.ObserveClientUpdateCatalogReload("success", 41)

	scrape := httptest.NewRecorder()
	recorder.Handler().ServeHTTP(scrape, httptest.NewRequest(http.MethodGet, "/metrics", nil))
	metrics := scrape.Body.String()
	for _, want := range []string{
		`voice_platform_client_update_checks_total{platform="web",result="published"} 1`,
		`voice_platform_client_release_catalog_reload_total{result="success"} 1`,
		`voice_platform_client_release_catalog_valid 1`,
		`voice_platform_client_release_catalog_revision 41`,
	} {
		if !strings.Contains(metrics, want) {
			t.Fatalf("metrics lack %q: %q", want, metrics)
		}
	}
	if strings.Contains(metrics, "release_id") {
		t.Fatalf("metrics leaked release identity: %q", metrics)
	}
}

func TestRecorderPublishesRosterSnapshotRateAndLatencyWithoutIdentity(t *testing.T) {
	recorder := New()
	recorder.ObserveVoiceRosterSnapshot(42*time.Millisecond, 3, false)
	scrape := httptest.NewRecorder()
	recorder.Handler().ServeHTTP(scrape, httptest.NewRequest(http.MethodGet, "/metrics", nil))
	metrics := scrape.Body.String()
	for _, want := range []string{
		`voice_platform_voice_roster_snapshots_total{outcome="success"} 1`,
		`voice_platform_voice_roster_snapshot_seconds_count 1`,
		`voice_platform_voice_roster_requested_rooms_count 1`,
	} {
		if !strings.Contains(metrics, want) {
			t.Fatalf("metrics lack %q", want)
		}
	}
	if strings.Contains(metrics, "voice:22222222") {
		t.Fatal("room ID leaked")
	}
}

func TestRecorderPublishesRosterFailureStageWithoutErrorDetails(t *testing.T) {
	recorder := New()
	recorder.ObserveVoiceRosterFailure("presence_snapshot")
	recorder.ObserveVoiceRosterFailure("visibility_initial")
	recorder.ObserveVoiceRosterFailure("untrusted error text")
	scrape := httptest.NewRecorder()
	recorder.Handler().ServeHTTP(scrape, httptest.NewRequest(http.MethodGet, "/metrics", nil))
	metrics := scrape.Body.String()
	for _, want := range []string{
		`voice_platform_voice_roster_failures_total{stage="presence_snapshot"} 1`,
		`voice_platform_voice_roster_failures_total{stage="visibility_initial"} 1`,
		`voice_platform_voice_roster_failures_total{stage="unknown"} 1`,
	} {
		if !strings.Contains(metrics, want) {
			t.Fatalf("metrics lack %q: %q", want, metrics)
		}
	}
	for _, forbidden := range []string{"sensitive database detail", "account_id", "channel_id", "lease_id"} {
		if strings.Contains(metrics, forbidden) {
			t.Fatalf("metrics contain error detail or identity field %q", forbidden)
		}
	}
}

func TestRecorderPublishesRealtimeConnectionMetrics(t *testing.T) {
	recorder := New()
	recorder.RealtimeConnectionOpened()
	recorder.ObserveRealtimeConnectionReady(25 * time.Millisecond)
	recorder.ObserveRealtimeSessionRevalidation(5*time.Millisecond, false)
	recorder.ObserveRealtimeConnectionRejected()
	recorder.RealtimeConnectionClosed()

	scrape := httptest.NewRecorder()
	recorder.Handler().ServeHTTP(scrape, httptest.NewRequest(http.MethodGet, "/metrics", nil))
	metrics := scrape.Body.String()
	for _, line := range []string{
		`voice_platform_realtime_connections_active{scope="authenticated"} 0`,
		"voice_platform_realtime_connections_total 1",
		"voice_platform_realtime_connection_ready_seconds_count 1",
		"voice_platform_realtime_session_revalidation_seconds_count 1",
		"voice_platform_realtime_session_revalidation_failures_total 1",
		"voice_platform_realtime_connections_rejected_total 1",
	} {
		if !strings.Contains(metrics, line) {
			t.Fatalf("metrics lack %q: %q", line, metrics)
		}
	}
	for _, value := range []string{"user-1", "vp_session", "connection.ready", "/api/v1/realtime"} {
		if strings.Contains(metrics, value) {
			t.Fatalf("metrics leaked %q: %q", value, metrics)
		}
	}
}
