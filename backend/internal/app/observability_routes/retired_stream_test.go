package observabilityroutes

import (
	"net/http"
	"net/http/httptest"
	"testing"

	maintenance "voice-platform/backend/internal/maintenance/admission"
	metrics "voice-platform/backend/internal/observability/http_metrics"
)

func TestMaintenanceStreamRouteIsRetired(t *testing.T) {
	mux := http.NewServeMux()
	ConfigureStatusRoutes(mux, maintenance.New(statusMaintenanceStore{}), metrics.New())
	request := httptest.NewRequest(http.MethodGet, "/api/v1/maintenance/events", nil)
	if _, pattern := mux.Handler(request); pattern != "" {
		t.Fatalf("retired route remains registered: %s", pattern)
	}
}
