package observehttprequests

import (
	"net/http"
	"strings"
)

func Method(method string) string {
	switch method {
	case "GET", "HEAD", "POST", "PUT", "PATCH", "DELETE", "OPTIONS", "CONNECT", "TRACE":
		return method
	default:
		return "OTHER"
	}
}
func Route(r *http.Request, mux *http.ServeMux) string {
	if mux == nil {
		return "unmatched"
	}
	_, pattern := mux.Handler(r)
	if pattern == "" {
		return "unmatched"
	}
	if _, path, ok := strings.Cut(pattern, " "); ok {
		pattern = path
	}
	return pattern
}
func Operation(path string) string {
	switch path {
	case "/metrics":
		return "metrics_scrape"
	case "/api/v1/health":
		return "health"
	case "/api/v1/maintenance":
		return "maintenance"
	case "/api/v1/auth/session":
		return "session_probe"
	case "/api/v1/telemetry/traces":
		return "trace_relay"
	case "/api/v1/voice/screen-metrics":
		return "screen_report"
	case "/internal/media-admission":
		return "media_admission"
	case "/internal/livekit/roster":
		return "roster_hook"
	default:
		return ""
	}
}
