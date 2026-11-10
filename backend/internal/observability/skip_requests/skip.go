package skiprequests

import "net/http"

// Skip marks fixed operational endpoints that should not generate their own
// spans, normal API metrics or access log entries. Operational aggregates remain safe.
func Skip(request *http.Request) bool {
	switch request.URL.Path {
	case "/metrics", "/api/v1/health", "/api/v1/maintenance",
		"/api/v1/auth/session", "/api/v1/telemetry/traces",
		"/api/v1/voice/screen-metrics",
		"/internal/media-admission", "/internal/livekit/roster":
		return true
	default:
		return false
	}
}
