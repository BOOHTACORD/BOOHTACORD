package referenceapi

import (
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"time"
	auth "voice-platform/backend/internal/identity/authenticate_session/api"
	"voice-platform/backend/internal/notifications/attention"
	resolve "voice-platform/backend/internal/notifications/resolve_reference"
	rate "voice-platform/backend/internal/security/rate_limit"
)

type Handler struct {
	Resolve   resolve.Store
	Attention attention.Store
	Limiter   *rate.Limiter
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
	if h.Limiter != nil {
		if _, ok = h.Limiter.Allow(actor.AccountID); !ok {
			w.Header().Set("Retry-After", "1")
			reply(w, 429, nil)
			return
		}
	}
	var result any
	var err error
	switch r.URL.Path {
	case "/api/v1/notification-attention":
		var in attention.Input
		if strict(w, r, &in) != nil {
			reply(w, 400, nil)
			return
		}
		err = h.Attention.Update(r.Context(), actor.AccountID, actor.SessionDigest, in, time.Now().UTC())
	case "/api/v1/notification-references/resolve", "/api/v1/notification-references/presented":
		var in resolve.Request
		if strict(w, r, &in) != nil {
			reply(w, 400, nil)
			return
		}
		if r.URL.Path == "/api/v1/notification-references/resolve" {
			result, err = h.Resolve.Resolve(r.Context(), actor.AccountID, in, time.Now().UTC())
		} else {
			err = h.Resolve.Presented(r.Context(), actor.AccountID, actor.SessionDigest, in, time.Now().UTC())
		}
	default:
		reply(w, 404, nil)
		return
	}
	if errors.Is(err, resolve.ErrNotFound) || errors.Is(err, attention.ErrUnavailable) {
		reply(w, 404, nil)
		return
	}
	if errors.Is(err, attention.ErrInvalid) {
		reply(w, 400, nil)
		return
	}
	if err != nil {
		reply(w, 500, nil)
		return
	}
	if result == nil {
		w.WriteHeader(204)
		return
	}
	reply(w, 200, result)
}
func strict(w http.ResponseWriter, r *http.Request, out any) error {
	d := json.NewDecoder(http.MaxBytesReader(w, r.Body, 4096))
	d.DisallowUnknownFields()
	if err := d.Decode(out); err != nil {
		return err
	}
	if d.Decode(&struct{}{}) != io.EOF {
		return attention.ErrInvalid
	}
	return nil
}
func reply(w http.ResponseWriter, status int, value any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(status)
	if value == nil {
		value = map[string]any{"error": map[string]string{"code": http.StatusText(status), "message": http.StatusText(status)}}
	}
	_ = json.NewEncoder(w).Encode(value)
}
