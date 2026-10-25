package preferencesapi

import (
	"context"
	"net/http"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	p "voice-platform/backend/internal/notifications/preferences"
)

type Service interface {
	Read(context.Context, string) (p.Settings, error)
	Save(context.Context, p.Input) (p.Settings, error)
}
type Access interface {
	Allowed(context.Context, string, p.Override) (bool, error)
}
type Publisher interface{ Changed(string, int64) }
type handler struct {
	service   Service
	access    Access
	available bool
	publisher Publisher
}

func NewHandler(service Service, access Access, available bool, publisher Publisher) http.Handler {
	return handler{service, access, available, publisher}
}
func (h handler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	principal, ok := sessionapi.PrincipalFrom(r.Context())
	if !ok {
		writeError(w, 401, "UNAUTHENTICATED")
		return
	}
	if expected := r.Header.Get("X-Notification-Account"); expected != "" && expected != principal.AccountID {
		writeError(w, 409, "ACCOUNT_CHANGED")
		return
	}
	switch r.URL.Path {
	case "/api/v1/notification-preferences":
		switch r.Method {
		case http.MethodGet:
			h.read(w, r, principal.AccountID)
		case http.MethodPut:
			h.update(w, r, principal.AccountID, false)
		default:
			writeError(w, 405, "METHOD_NOT_ALLOWED")
		}
	case "/api/v1/notification-preferences/import":
		if r.Method != http.MethodPost {
			writeError(w, 405, "METHOD_NOT_ALLOWED")
			return
		}
		h.update(w, r, principal.AccountID, true)
	default:
		writeError(w, 404, "NOT_FOUND")
	}
}
func (h handler) read(w http.ResponseWriter, r *http.Request, actor string) {
	settings, err := h.service.Read(r.Context(), actor)
	if err != nil {
		writeServiceError(w, err)
		return
	}
	kept := make([]p.Override, 0, len(settings.Overrides))
	for _, override := range settings.Overrides {
		allowed, err := h.access.Allowed(r.Context(), actor, override)
		if err != nil {
			writeError(w, 503, "ACCESS_UNAVAILABLE")
			return
		}
		if allowed {
			kept = append(kept, override)
		}
	}
	settings.Overrides = kept
	h.writeSettings(w, settings)
}
func (h handler) update(w http.ResponseWriter, r *http.Request, actor string, importing bool) {
	input, err := decodeInput(w, r, importing)
	if err != nil {
		writeError(w, 400, "VALIDATION_FAILED")
		return
	}
	input.AccountID = actor
	if err = p.Validate(input); err != nil {
		writeServiceError(w, err)
		return
	}
	for _, override := range input.Settings.Overrides {
		allowed, err := h.access.Allowed(r.Context(), actor, override)
		if err != nil {
			writeError(w, 503, "ACCESS_UNAVAILABLE")
			return
		}
		if !allowed {
			writeError(w, 404, "NOT_FOUND")
			return
		}
	}
	saved, err := h.service.Save(r.Context(), input)
	if err != nil {
		writeServiceError(w, err)
		return
	}
	if h.publisher != nil {
		h.publisher.Changed(actor, saved.Revision)
	}
	h.writeSettings(w, saved)
}
