package issuelivekitcredentialapi

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"time"

	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	issuelivekitcredential "voice-platform/backend/internal/media/issue_livekit_credential"
	livekitcredential "voice-platform/backend/internal/media/livekit_credential"
	"voice-platform/backend/internal/security/request_id"
)

type Issuer interface {
	Issue(context.Context, issuelivekitcredential.Input) (livekitcredential.Credential, error)
}

func NewHandler(issuer Issuer) http.Handler {
	return http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		if request.Method != http.MethodPost {
			writer.WriteHeader(http.StatusMethodNotAllowed)
			return
		}
		principal, ok := sessionapi.PrincipalFrom(request.Context())
		if !ok {
			writeError(writer, request, http.StatusInternalServerError, "INTERNAL", "Не удалось выдать media credential")
			return
		}
		credential, err := issuer.Issue(request.Context(), issuelivekitcredential.Input{ActorID: principal.AccountID, LeaseID: request.PathValue("leaseID"), SessionDigest: principal.SessionDigest})
		if errors.Is(err, issuelivekitcredential.ErrInvalidInput) {
			writeError(writer, request, http.StatusBadRequest, "VALIDATION_FAILED", "Некорректный идентификатор голосового подключения")
			return
		}
		if errors.Is(err, issuelivekitcredential.ErrLeaseUnavailable) {
			writeError(writer, request, http.StatusConflict, "VOICE_LEASE_UNAVAILABLE", "Голосовое подключение больше не активно")
			return
		}
		if err != nil {
			writeError(writer, request, http.StatusInternalServerError, "INTERNAL", "Не удалось выдать media credential")
			return
		}
		writer.Header().Set("Content-Type", "application/json; charset=utf-8")
		_ = json.NewEncoder(writer).Encode(struct {
			URL               string    `json:"url"`
			Token             string    `json:"token"`
			ExpiresAt         time.Time `json:"expires_at"`
			MicrophoneAllowed bool      `json:"microphone_allowed"`
		}{credential.URL, credential.Token, credential.ExpiresAt, credential.MicrophoneAllowed})
	})
}
func writeError(writer http.ResponseWriter, request *http.Request, status int, code, message string) {
	writer.Header().Set("Content-Type", "application/json; charset=utf-8")
	writer.WriteHeader(status)
	_ = json.NewEncoder(writer).Encode(map[string]any{"error": map[string]string{"code": code, "message": message, "request_id": requestid.From(request.Context())}})
}
