package passwordapi

import (
	"encoding/json"
	"errors"
	"net/http"

	"voice-platform/backend/internal/identity/password"
	"voice-platform/backend/internal/security/request_id"
)

// WriteBusy distinguishes process capacity from invalid credentials. Clients
// keep the editable form and retry manually; no password is queued server-side.
func WriteBusy(w http.ResponseWriter, r *http.Request, err error) bool {
	if !errors.Is(err, password.ErrBusy) {
		return false
	}
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.Header().Set("Retry-After", "1")
	w.Header().Set("Cache-Control", "no-store")
	w.WriteHeader(http.StatusServiceUnavailable)
	_ = json.NewEncoder(w).Encode(map[string]any{"error": map[string]string{
		"code":       "AUTH_BUSY",
		"message":    "Сервер занят. Повторите вручную через 1 с.",
		"request_id": requestid.From(r.Context()),
	}})
	return true
}
