package observabilityroutes

import (
	"net/http"

	"voice-platform/backend/internal/health"
	maintenanceadmission "voice-platform/backend/internal/maintenance/admission"
	maintenanceapi "voice-platform/backend/internal/maintenance/admission/api"
	httpmetrics "voice-platform/backend/internal/observability/http_metrics"
)

func ConfigureStatusRoutes(mux *http.ServeMux, maintenance maintenanceadmission.Service, metrics *httpmetrics.Recorder) {
	mux.Handle("GET /api/v1/health", health.NewHandler())
	mux.Handle("GET /api/v1/maintenance", maintenanceapi.NewHandler(maintenance))
	mux.Handle("GET /metrics", metrics.Handler())
}
