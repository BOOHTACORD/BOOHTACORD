package activationapi

import (
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"time"
	auth "voice-platform/backend/internal/identity/authenticate_session/api"
	activate "voice-platform/backend/internal/notifications/activate_device"
	d "voice-platform/backend/internal/notifications/register_device"
	rate "voice-platform/backend/internal/security/rate_limit"
)

type Handler struct {
	Service activate.Service
	Limiter *rate.Limiter
	Ready   bool
}

func (h Handler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Cache-Control", "no-store")
	actor, ok := auth.PrincipalFrom(r.Context())
	if !ok {
		reply(w, 401, nil)
		return
	}
	if expected := r.Header.Get("X-Notification-Account"); expected != "" && expected != actor.AccountID {
		reply(w, 409, nil)
		return
	}
	if !h.Ready {
		reply(w, 503, nil)
		return
	}
	if h.Limiter != nil {
		if _, ok = h.Limiter.Allow(actor.AccountID); !ok {
			w.Header().Set("Retry-After", "60")
			reply(w, 429, nil)
			return
		}
	}
	var in activate.Input
	decoder := json.NewDecoder(http.MaxBytesReader(w, r.Body, 12<<10))
	decoder.DisallowUnknownFields()
	if decoder.Decode(&in) != nil || decoder.Decode(&struct{}{}) != io.EOF {
		reply(w, 400, nil)
		return
	}
	record, err := h.Service.Activate(r.Context(), actor.AccountID, actor.SessionDigest, r.PathValue("deviceID"), in, time.Now().UTC())
	switch {
	case errors.Is(err, d.ErrInvalid):
		reply(w, 400, nil)
	case errors.Is(err, d.ErrConflict):
		reply(w, 409, nil)
	case errors.Is(err, activate.ErrNotFound):
		reply(w, 404, nil)
	case errors.Is(err, d.ErrUnauthorized):
		reply(w, 401, nil)
	case errors.Is(err, d.ErrUnavailable):
		reply(w, 503, nil)
	case err != nil:
		reply(w, 500, nil)
	default:
		reply(w, 200, map[string]any{"version": 1, "account_id": actor.AccountID, "device": record})
	}
}
func reply(w http.ResponseWriter, status int, value any) {
	if value == nil {
		value = map[string]any{"error": map[string]string{"code": http.StatusText(status), "message": http.StatusText(status)}}
	}
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(value)
}
