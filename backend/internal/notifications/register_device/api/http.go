package deviceapi

import (
	"encoding/json"
	"errors"
	"github.com/google/uuid"
	"io"
	"net/http"
	d "voice-platform/backend/internal/notifications/register_device"
	revoke "voice-platform/backend/internal/notifications/revoke_device"
)

func validID(raw string) bool {
	id, err := uuid.Parse(raw)
	return err == nil && id != uuid.Nil && id.String() == raw
}
func strict(w http.ResponseWriter, r *http.Request, value any) error {
	decoder := json.NewDecoder(http.MaxBytesReader(w, r.Body, 16<<10))
	decoder.DisallowUnknownFields()
	if err := decoder.Decode(value); err != nil {
		return d.ErrInvalid
	}
	if decoder.Decode(&struct{}{}) != io.EOF {
		return d.ErrInvalid
	}
	return nil
}
func reply(w http.ResponseWriter, status int, value any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.Header().Set("Cache-Control", "no-store")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(value)
}
func failure(w http.ResponseWriter, status int, code string) {
	reply(w, status, map[string]any{"error": map[string]string{"code": code, "message": http.StatusText(status)}})
}
func writeError(w http.ResponseWriter, err error) {
	switch {
	case errors.Is(err, d.ErrInvalid):
		failure(w, 400, "VALIDATION_FAILED")
	case errors.Is(err, d.ErrUnauthorized):
		failure(w, 401, "UNAUTHENTICATED")
	case errors.Is(err, d.ErrConflict):
		failure(w, 409, "GENERATION_CONFLICT")
	case errors.Is(err, d.ErrLimit):
		w.Header().Set("Retry-After", "60")
		failure(w, 429, "DEVICE_LIMIT")
	case errors.Is(err, d.ErrUnavailable):
		failure(w, 503, "UNAVAILABLE")
	case errors.Is(err, revoke.ErrNotFound):
		failure(w, 404, "NOT_FOUND")
	default:
		failure(w, 500, "INTERNAL")
	}
}
