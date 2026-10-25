package relayapi

import (
	"bytes"
	"encoding/json"
	"errors"
	"io"
	"mime"
	"net/http"
	accept "voice-platform/backend/internal/pushrelay/accept_notification"
	auth "voice-platform/backend/internal/pushrelay/authorize_request"
	enroll "voice-platform/backend/internal/pushrelay/enroll_device"
	pair "voice-platform/backend/internal/pushrelay/pair_installation"
	signature "voice-platform/backend/internal/pushrelay/request_signature"
	revoke "voice-platform/backend/internal/pushrelay/revoke_grant"
)

func body(w http.ResponseWriter, r *http.Request, out any) ([]byte, error) {
	media, _, err := mime.ParseMediaType(r.Header.Get("Content-Type"))
	if err != nil || media != "application/json" {
		return nil, auth.ErrDenied
	}
	raw, err := io.ReadAll(http.MaxBytesReader(w, r.Body, 16384))
	if err != nil {
		return nil, err
	}
	decoder := json.NewDecoder(bytes.NewReader(raw))
	decoder.DisallowUnknownFields()
	if err = decoder.Decode(out); err != nil {
		return nil, err
	}
	if decoder.Decode(&struct{}{}) != io.EOF {
		return nil, auth.ErrDenied
	}
	return raw, nil
}
func signed(r *http.Request, raw []byte) signature.Request {
	return signature.Request{Method: r.Method, Path: r.URL.Path, Role: r.Header.Get("X-Relay-Role"), Subject: r.Header.Get("X-Relay-Subject"), Timestamp: r.Header.Get("X-Relay-Timestamp"), Nonce: r.Header.Get("X-Relay-Nonce"), Signature: r.Header.Get("X-Relay-Signature"), Body: raw}
}
func reply(w http.ResponseWriter, status int, value any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(value)
}
func failure(w http.ResponseWriter, status int, code string) {
	reply(w, status, map[string]any{"error": map[string]string{"code": code, "message": http.StatusText(status)}})
}
func writeError(w http.ResponseWriter, err error) {
	switch {
	case errors.Is(err, accept.ErrRouteUnavailable):
		failure(w, 404, "ROUTE_UNAVAILABLE")
	case errors.Is(err, auth.ErrDenied):
		failure(w, 403, "FORBIDDEN")
	case errors.Is(err, auth.ErrLimit):
		w.Header().Set("Retry-After", "60")
		failure(w, 429, "CAPACITY_LIMIT")
	case errors.Is(err, enroll.ErrConflict) || errors.Is(err, pair.ErrConflict) || errors.Is(err, accept.ErrConflict):
		failure(w, 409, "CONFLICT")
	case errors.Is(err, enroll.ErrInvalid) || errors.Is(err, pair.ErrInvalid) || errors.Is(err, accept.ErrInvalid):
		failure(w, 400, "INVALID_REQUEST")
	case errors.Is(err, revoke.ErrNotFound) || errors.Is(err, accept.ErrNotFound):
		failure(w, 404, "NOT_FOUND")
	default:
		failure(w, 500, "INTERNAL")
	}
}
