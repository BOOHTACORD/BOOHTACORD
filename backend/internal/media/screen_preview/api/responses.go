package screenpreviewapi

import (
	"encoding/json"
	"errors"
	"net/http"

	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	screenpreview "voice-platform/backend/internal/media/screen_preview"
	"voice-platform/backend/internal/security/request_id"
)

func principal(request *http.Request) (screenpreview.Principal, bool) {
	value, ok := sessionapi.PrincipalFrom(request.Context())
	return screenpreview.Principal{AccountID: value.AccountID, SessionDigest: value.SessionDigest}, ok
}

func writeFailure(writer http.ResponseWriter, request *http.Request, err error) {
	status, code := http.StatusServiceUnavailable, "PREVIEW_UNAVAILABLE"
	switch {
	case errors.Is(err, screenpreview.ErrDenied), errors.Is(err, screenpreview.ErrNotFound):
		status, code = http.StatusNotFound, "PREVIEW_NOT_FOUND"
	case errors.Is(err, screenpreview.ErrInvalidInput), errors.Is(err, screenpreview.ErrInvalidJPEG):
		status, code = http.StatusBadRequest, "VALIDATION_FAILED"
	case errors.Is(err, screenpreview.ErrStaleGeneration):
		status, code = http.StatusConflict, "PREVIEW_GENERATION_STALE"
	case errors.Is(err, screenpreview.ErrRateLimited):
		status, code = http.StatusTooManyRequests, "PREVIEW_RATE_LIMITED"
		writer.Header().Set("Retry-After", "4")
	case errors.Is(err, screenpreview.ErrServerManaged):
		status, code = http.StatusGone, "PREVIEW_SERVER_MANAGED"
	case errors.Is(err, screenpreview.ErrNoUpdate):
		writer.WriteHeader(http.StatusNoContent)
		return
	}
	writer.Header().Set("Content-Type", "application/json; charset=utf-8")
	writer.WriteHeader(status)
	_ = json.NewEncoder(writer).Encode(map[string]any{"error": map[string]string{
		"code": code, "message": "Превью экрана сейчас недоступно", "request_id": requestid.From(request.Context()),
	}})
}

func writeBadRequest(writer http.ResponseWriter, request *http.Request) {
	writeFailure(writer, request, screenpreview.ErrInvalidInput)
}
