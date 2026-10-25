package preferencesapi

import (
	"encoding/json"
	"errors"
	"net/http"
	p "voice-platform/backend/internal/notifications/preferences"
)

func writeJSON(w http.ResponseWriter, status int, value any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.Header().Set("Cache-Control", "no-store")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(value)
}
func (h handler) writeSettings(w http.ResponseWriter, settings p.Settings) {
	writeJSON(w, 200, map[string]any{"capability": map[string]any{"version": 1, "available": h.available, "device_transport": "unavailable"}, "settings": settings})
}
func writeError(w http.ResponseWriter, status int, code string) {
	writeJSON(w, status, map[string]any{"error": map[string]string{"code": code, "message": http.StatusText(status)}})
}
func writeServiceError(w http.ResponseWriter, err error) {
	switch {
	case errors.Is(err, p.ErrInvalid):
		writeError(w, 400, "VALIDATION_FAILED")
	case errors.Is(err, p.ErrAlreadyImported):
		writeError(w, 409, "ALREADY_IMPORTED")
	case errors.Is(err, p.ErrConflict):
		writeError(w, 409, "CONFLICT")
	default:
		writeError(w, 500, "INTERNAL")
	}
}
