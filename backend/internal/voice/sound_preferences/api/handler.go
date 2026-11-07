package soundapi

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	session "voice-platform/backend/internal/identity/authenticate_session/api"
	p "voice-platform/backend/internal/voice/sound_preferences"
)

type Service interface {
	Read(context.Context, string) (p.Snapshot, error)
	Save(context.Context, string, int64, p.Settings) (p.Snapshot, error)
}
type handler struct{ service Service }

func NewHandler(service Service) http.Handler { return handler{service} }
func (h handler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	principal, ok := session.PrincipalFrom(r.Context())
	if !ok {
		respond(w, 401, nil)
		return
	}
	if expected := r.Header.Get("X-Voice-Sound-Account"); expected != "" && expected != principal.AccountID {
		respond(w, 409, nil)
		return
	}
	switch r.Method {
	case http.MethodGet:
		value, err := h.service.Read(r.Context(), principal.AccountID)
		if err != nil {
			respond(w, 500, nil)
			return
		}
		respond(w, 200, value)
	case http.MethodPatch:
		patch, err := decodePatch(w, r)
		if err != nil {
			respond(w, 400, nil)
			return
		}
		current, err := h.service.Read(r.Context(), principal.AccountID)
		if err != nil {
			respond(w, 500, nil)
			return
		}
		if current.Revision != patch.Revision {
			respond(w, 409, nil)
			return
		}
		value := patch.apply(current.Settings)
		if value.Validate() != nil {
			respond(w, 400, nil)
			return
		}
		saved, err := h.service.Save(r.Context(), principal.AccountID, patch.Revision, value)
		if errors.Is(err, p.ErrConflict) {
			respond(w, 409, nil)
			return
		}
		if err != nil {
			respond(w, 500, nil)
			return
		}
		respond(w, 200, saved)
	default:
		respond(w, 405, nil)
	}
}
func respond(w http.ResponseWriter, status int, value any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.Header().Set("Cache-Control", "no-store")
	w.WriteHeader(status)
	if value == nil {
		value = map[string]any{"error": map[string]string{"message": http.StatusText(status)}}
	}
	_ = json.NewEncoder(w).Encode(value)
}
