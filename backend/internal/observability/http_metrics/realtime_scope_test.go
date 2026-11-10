package httpmetrics

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func TestRealtimeScopesTrackIndependentActiveConnections(t *testing.T) {
	recorder := New()
	recorder.RealtimeConnectionOpened()
	recorder.PublicRealtimeConnectionOpened()
	recorder.PublicRealtimeConnectionOpened()
	recorder.PublicRealtimeConnectionClosed()
	response := httptest.NewRecorder()
	recorder.Handler().ServeHTTP(response, httptest.NewRequest(http.MethodGet, "/metrics", nil))
	for _, expected := range []string{
		`voice_platform_realtime_connections_active{scope="authenticated"} 1`,
		`voice_platform_realtime_connections_active{scope="public"} 1`,
	} {
		if !strings.Contains(response.Body.String(), expected) {
			t.Fatalf("missing %s", expected)
		}
	}
	recorder.RealtimeConnectionClosed()
	recorder.PublicRealtimeConnectionClosed()
}
