package api

import (
	"context"
	"encoding/json"
	"errors"
	"io"
	"net/http"

	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	relay "voice-platform/backend/internal/media/screen_telemetry_relay"
	requestid "voice-platform/backend/internal/security/request_id"
)

type Operations interface {
	Publish(context.Context, relay.Principal, string, relay.ScreenTelemetryEnvelopeV1) error
}

type Handler struct{ operations Operations }

func RegisterRoutes(mux *http.ServeMux, sessions sessionapi.Authenticator, operations Operations) {
	handler := &Handler{operations: operations}
	mux.Handle("POST /api/v1/voice/leases/{ownerLeaseID}/screen-telemetry", privateHeaders(sessionapi.Require(sessions)(http.HandlerFunc(handler.publish))))
}

func (handler *Handler) publish(writer http.ResponseWriter, request *http.Request) {
	var envelope relay.ScreenTelemetryEnvelopeV1
	decoder := json.NewDecoder(http.MaxBytesReader(writer, request.Body, relay.MaxEnvelopeBytes))
	decoder.DisallowUnknownFields()
	if err := decoder.Decode(&envelope); err != nil {
		writeFailure(writer, request, relay.ErrInvalid)
		return
	}
	if err := decoder.Decode(&struct{}{}); !errors.Is(err, io.EOF) {
		writeFailure(writer, request, relay.ErrInvalid)
		return
	}
	principal, ok := sessionapi.PrincipalFrom(request.Context())
	if !ok {
		writeFailure(writer, request, relay.ErrUnavailable)
		return
	}
	err := handler.operations.Publish(request.Context(), relay.Principal{AccountID: principal.AccountID, SessionDigest: principal.SessionDigest}, request.PathValue("ownerLeaseID"), envelope)
	if err != nil {
		writeFailure(writer, request, err)
		return
	}
	writer.WriteHeader(http.StatusNoContent)
}

func privateHeaders(next http.Handler) http.Handler {
	return http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		writer.Header().Set("Cache-Control", "private, no-store, max-age=0")
		writer.Header().Set("Pragma", "no-cache")
		writer.Header().Set("Expires", "0")
		writer.Header().Set("X-Content-Type-Options", "nosniff")
		writer.Header().Set("Vary", "Cookie")
		next.ServeHTTP(writer, request)
	})
}

func writeFailure(writer http.ResponseWriter, request *http.Request, err error) {
	status, code, message := http.StatusServiceUnavailable, "SCREEN_TELEMETRY_UNAVAILABLE", "Не удалось передать диагностику трансляции"
	switch {
	case errors.Is(err, relay.ErrDenied):
		status, code = http.StatusNotFound, "VOICE_PARTICIPANT_NOT_FOUND"
	case errors.Is(err, relay.ErrInvalid):
		status, code = http.StatusBadRequest, "VALIDATION_FAILED"
	case errors.Is(err, relay.ErrStale):
		status, code = http.StatusConflict, "SCREEN_TELEMETRY_STALE"
	case errors.Is(err, relay.ErrRateLimited):
		status, code = http.StatusTooManyRequests, "SCREEN_TELEMETRY_RATE_LIMITED"
	case errors.Is(err, relay.ErrCapacity):
		status, code = http.StatusServiceUnavailable, "SCREEN_TELEMETRY_UNAVAILABLE"
	}
	writer.Header().Set("Content-Type", "application/json; charset=utf-8")
	writer.WriteHeader(status)
	_ = json.NewEncoder(writer).Encode(map[string]any{"error": map[string]string{
		"code": code, "message": message, "request_id": requestid.From(request.Context()),
	}})
}
