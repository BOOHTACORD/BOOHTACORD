package api

import (
	"context"
	"encoding/json"
	"errors"
	"io"
	"net/http"

	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	presence "voice-platform/backend/internal/media/screen_viewer_presence"
	"voice-platform/backend/internal/security/request_id"
)

type Operations interface {
	Watch(context.Context, presence.Principal, string, string, string) error
	StopWatching(context.Context, presence.Principal, string, string, string) error
	Viewers(context.Context, presence.Principal, string) ([]string, error)
	ClearOwner(context.Context, presence.Principal, string, string) error
}

type Handler struct{ operations Operations }

func RegisterRoutes(mux *http.ServeMux, sessions sessionapi.Authenticator, operations Operations) {
	handler := &Handler{operations: operations}
	protect := func(next http.Handler) http.Handler { return privateHeaders(sessionapi.Require(sessions)(next)) }
	mux.Handle("PUT /api/v1/voice/leases/{viewerLeaseID}/screen-viewers/{ownerLeaseID}", protect(http.HandlerFunc(handler.watch)))
	mux.Handle("DELETE /api/v1/voice/leases/{viewerLeaseID}/screen-viewers/{ownerLeaseID}", protect(http.HandlerFunc(handler.stopWatching)))
	mux.Handle("GET /api/v1/voice/leases/{ownerLeaseID}/screen-viewers", protect(http.HandlerFunc(handler.viewers)))
	mux.Handle("DELETE /api/v1/voice/leases/{ownerLeaseID}/screen-viewers", protect(http.HandlerFunc(handler.clearOwner)))
}

func (handler *Handler) watch(writer http.ResponseWriter, request *http.Request) {
	var body struct {
		TrackSID string `json:"track_sid"`
	}
	decoder := json.NewDecoder(http.MaxBytesReader(writer, request.Body, 1024))
	decoder.DisallowUnknownFields()
	if err := decoder.Decode(&body); err != nil {
		writeFailure(writer, request, presence.ErrInvalidInput)
		return
	}
	if err := decoder.Decode(&struct{}{}); !errors.Is(err, io.EOF) {
		writeFailure(writer, request, presence.ErrInvalidInput)
		return
	}
	principal, ok := principal(request)
	if !ok {
		writeFailure(writer, request, presence.ErrUnavailable)
		return
	}
	if err := handler.operations.Watch(request.Context(), principal, request.PathValue("viewerLeaseID"), request.PathValue("ownerLeaseID"), body.TrackSID); err != nil {
		writeFailure(writer, request, err)
		return
	}
	writer.WriteHeader(http.StatusNoContent)
}

func (handler *Handler) stopWatching(writer http.ResponseWriter, request *http.Request) {
	principal, ok := principal(request)
	if !ok {
		writeFailure(writer, request, presence.ErrUnavailable)
		return
	}
	if err := handler.operations.StopWatching(request.Context(), principal, request.PathValue("viewerLeaseID"), request.PathValue("ownerLeaseID"), request.URL.Query().Get("track_sid")); err != nil {
		writeFailure(writer, request, err)
		return
	}
	writer.WriteHeader(http.StatusNoContent)
}

func (handler *Handler) viewers(writer http.ResponseWriter, request *http.Request) {
	principal, ok := principal(request)
	if !ok {
		writeFailure(writer, request, presence.ErrUnavailable)
		return
	}
	accounts, err := handler.operations.Viewers(request.Context(), principal, request.PathValue("ownerLeaseID"))
	if err != nil {
		writeFailure(writer, request, err)
		return
	}
	writer.Header().Set("Content-Type", "application/json; charset=utf-8")
	_ = json.NewEncoder(writer).Encode(map[string][]string{"viewer_account_ids": accounts})
}

func (handler *Handler) clearOwner(writer http.ResponseWriter, request *http.Request) {
	principal, ok := principal(request)
	if !ok {
		writeFailure(writer, request, presence.ErrUnavailable)
		return
	}
	if err := handler.operations.ClearOwner(request.Context(), principal, request.PathValue("ownerLeaseID"), request.URL.Query().Get("track_sid")); err != nil {
		writeFailure(writer, request, err)
		return
	}
	writer.WriteHeader(http.StatusNoContent)
}

func principal(request *http.Request) (presence.Principal, bool) {
	value, ok := sessionapi.PrincipalFrom(request.Context())
	return presence.Principal{AccountID: value.AccountID, SessionDigest: value.SessionDigest}, ok
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
	status, code := http.StatusServiceUnavailable, "SCREEN_VIEWERS_UNAVAILABLE"
	switch {
	case errors.Is(err, presence.ErrDenied):
		status, code = http.StatusNotFound, "VOICE_PARTICIPANT_NOT_FOUND"
	case errors.Is(err, presence.ErrInvalidInput):
		status, code = http.StatusBadRequest, "VALIDATION_FAILED"
	case errors.Is(err, presence.ErrCapacity):
		status, code = http.StatusServiceUnavailable, "SCREEN_VIEWERS_UNAVAILABLE"
	}
	writer.Header().Set("Content-Type", "application/json; charset=utf-8")
	writer.WriteHeader(status)
	_ = json.NewEncoder(writer).Encode(map[string]any{"error": map[string]string{
		"code": code, "message": "Не удалось обновить список зрителей трансляции", "request_id": requestid.From(request.Context()),
	}})
}
