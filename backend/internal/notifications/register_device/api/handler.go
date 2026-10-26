package deviceapi

import (
	"context"
	"net/http"
	"strconv"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	d "voice-platform/backend/internal/notifications/register_device"
	rate "voice-platform/backend/internal/security/rate_limit"
)

type Registrar interface {
	Register(context.Context, d.Input) (d.Enrollment, error)
}
type Lister interface {
	List(context.Context, string) ([]d.Record, error)
}
type Revoker interface {
	Revoke(context.Context, string, string, int64) error
}
type Handler struct {
	Register     Registrar
	List         Lister
	Revoke       Revoker
	Capabilities map[string]any
	Limiter      *rate.Limiter
	Ready        bool
}

func (h Handler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	actor, ok := sessionapi.PrincipalFrom(r.Context())
	if !ok {
		failure(w, 401, "UNAUTHENTICATED")
		return
	}
	w.Header().Set("Cache-Control", "no-store")
	if expected := r.Header.Get("X-Notification-Account"); expected != "" && expected != actor.AccountID {
		failure(w, 409, "ACCOUNT_CHANGED")
		return
	}
	if h.Limiter != nil {
		delay, ok := h.Limiter.Allow(actor.AccountID)
		if !ok {
			w.Header().Set("Retry-After", strconv.Itoa(max(1, int(delay.Seconds()))))
			failure(w, 429, "RATE_LIMITED")
			return
		}
	}
	if r.URL.Path == "/api/v1/notification-devices/capabilities" && r.Method == "GET" {
		capabilities := make(map[string]any, len(h.Capabilities)+1)
		for key, value := range h.Capabilities {
			capabilities[key] = value
		}
		capabilities["account_id"] = actor.AccountID
		capabilities["session_ref"] = d.SessionReference(actor.SessionDigest)
		reply(w, 200, capabilities)
		return
	}
	if !h.Ready {
		failure(w, 503, "UNAVAILABLE")
		return
	}
	switch r.Method {
	case "GET":
		records, err := h.List.List(r.Context(), actor.AccountID)
		if err != nil {
			writeError(w, err)
			return
		}
		reply(w, 200, map[string]any{"version": 1, "devices": records})
	case "POST", "PUT":
		var input d.Input
		if err := strict(w, r, &input); err != nil {
			failure(w, 400, "VALIDATION_FAILED")
			return
		}
		input.AccountID = actor.AccountID
		input.SessionDigest = actor.SessionDigest
		input.ID = r.PathValue("deviceID")
		if r.Method == "PUT" && !validID(input.ID) {
			failure(w, 400, "VALIDATION_FAILED")
			return
		}
		result, err := h.Register.Register(r.Context(), input)
		if err != nil {
			writeError(w, err)
			return
		}
		reply(w, 200, map[string]any{"version": 1, "account_id": actor.AccountID, "device": result.Device, "nonce": result.Nonce})
	case "DELETE":
		id := r.PathValue("deviceID")
		if !validID(id) {
			failure(w, 400, "VALIDATION_FAILED")
			return
		}
		var body struct {
			ExpectedGeneration int64 `json:"expected_generation"`
		}
		if strict(w, r, &body) != nil {
			failure(w, 400, "VALIDATION_FAILED")
			return
		}
		if err := h.Revoke.Revoke(r.Context(), actor.AccountID, id, body.ExpectedGeneration); err != nil {
			writeError(w, err)
			return
		}
		w.WriteHeader(204)
	default:
		failure(w, 405, "METHOD_NOT_ALLOWED")
	}
}
