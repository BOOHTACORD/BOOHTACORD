package observabilityroutes

import (
	"net/http"
	runtime "voice-platform/backend/internal/config/runtime"
	session "voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	installationapi "voice-platform/backend/internal/observability/installation/api"
)

func ConfigureInstallationRoutes(mux *http.ServeMux, sessions session.Service, c runtime.Config) {
	h := installationapi.Handler{Runtime: c.CentralTelemetry}
	mux.HandleFunc("GET /api/v1/installation", h.Public)
	mux.HandleFunc("POST /internal/telemetry/metrics", h.Agent)
	mux.Handle("GET /api/v1/admin/telemetry", sessionapi.Require(sessions)(sessionapi.RequireAdministrator(http.HandlerFunc(h.Read))))
	mux.Handle("PATCH /api/v1/admin/telemetry", sessionapi.Require(sessions)(sessionapi.RequireAdministrator(http.HandlerFunc(h.Patch))))
}
