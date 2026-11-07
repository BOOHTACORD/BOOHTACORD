package joinsoundapi

import (
	"encoding/json"
	"errors"
	"io"
	"net/http"
	s "voice-platform/backend/internal/voice/join_sound"
)

func reply(w http.ResponseWriter, status int, value any) {
	w.Header().Set("Cache-Control", "no-store")
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	if value == nil {
		value = map[string]any{"error": map[string]string{"message": http.StatusText(status)}}
	}
	_ = json.NewEncoder(w).Encode(value)
}
func failure(w http.ResponseWriter, err error) {
	status := 500
	switch {
	case errors.Is(err, s.ErrInvalid):
		status = 400
	case errors.Is(err, s.ErrNotFound):
		status = 404
	case errors.Is(err, s.ErrRateLimited):
		status = 429
		w.Header().Set("Retry-After", "10")
	case errors.Is(err, s.ErrUnavailable):
		status = 503
	}
	reply(w, status, nil)
}
func decodeEnabled(w http.ResponseWriter, r *http.Request) (bool, error) {
	var body struct {
		Enabled *bool `json:"enabled"`
	}
	d := json.NewDecoder(http.MaxBytesReader(w, r.Body, 256))
	d.DisallowUnknownFields()
	if err := d.Decode(&body); err != nil {
		return false, err
	}
	if body.Enabled == nil {
		return false, s.ErrInvalid
	}
	if err := d.Decode(&struct{}{}); !errors.Is(err, io.EOF) {
		return false, s.ErrInvalid
	}
	return *body.Enabled, nil
}
