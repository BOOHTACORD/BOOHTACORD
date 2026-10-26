package relayapi

import (
	"context"
	"net"
	"net/http"
	"strconv"
	"time"
	accept "voice-platform/backend/internal/pushrelay/accept_notification"
	enroll "voice-platform/backend/internal/pushrelay/enroll_device"
	pair "voice-platform/backend/internal/pushrelay/pair_installation"
	revoke "voice-platform/backend/internal/pushrelay/revoke_grant"
	rate "voice-platform/backend/internal/security/rate_limit"
)

type Handler struct {
	Enroll  enroll.Service
	Pair    pair.Service
	Accept  accept.Service
	Revoke  revoke.Store
	Ready   bool
	Limiter *rate.Limiter
	Health  func(context.Context) error
}

func (h Handler) Routes() http.Handler {
	mux := http.NewServeMux()
	for _, route := range []string{"GET /health", "POST /v1/devices/challenge", "POST /v1/devices/verify", "POST /v1/grants", "POST /v1/notifications", "POST /v1/receipts", "DELETE /v1/grants/{grantID}", "DELETE /v1/devices/{deviceID}"} {
		mux.Handle(route, h)
	}
	return mux
}
func (h Handler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Cache-Control", "no-store")
	if r.URL.Path == "/health" {
		ctx, cancel := context.WithTimeout(r.Context(), 2*time.Second)
		defer cancel()
		if h.Health != nil && h.Health(ctx) != nil {
			failure(w, 503, "UNAVAILABLE")
			return
		}
		reply(w, 200, map[string]any{"version": 1, "status": "ok", "provider_available": h.Ready})
		return
	}
	if r.Header.Get("Origin") != "" || r.URL.RawQuery != "" || r.URL.RawPath != "" {
		failure(w, 403, "FORBIDDEN")
		return
	}
	if h.Limiter != nil {
		host, _, err := net.SplitHostPort(r.RemoteAddr)
		if err != nil {
			host = "unknown"
		}
		if delay, ok := h.Limiter.Allow(host); !ok {
			w.Header().Set("Retry-After", strconv.Itoa(max(1, int(delay.Seconds()))))
			failure(w, 429, "RATE_LIMITED")
			return
		}
	}
	if !h.Ready && r.URL.Path != "/v1/receipts" && r.Method != "DELETE" {
		w.Header().Set("Retry-After", "60")
		failure(w, 503, "PROVIDER_UNAVAILABLE")
		return
	}
	switch r.URL.Path {
	case "/v1/devices/challenge":
		h.challenge(w, r)
	case "/v1/devices/verify":
		h.verify(w, r)
	case "/v1/grants":
		h.pair(w, r)
	case "/v1/notifications":
		h.accept(w, r)
	case "/v1/receipts":
		h.status(w, r)
	default:
		if r.Method == "DELETE" {
			h.revoke(w, r)
			return
		}
		failure(w, 404, "NOT_FOUND")
	}
}
