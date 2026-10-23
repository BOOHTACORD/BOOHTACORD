package resetapi

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	passwordapi "voice-platform/backend/internal/identity/password/api"

	"voice-platform/backend/internal/identity/complete_password_reset"
	"voice-platform/backend/internal/security/request_id"
)

type Completer interface {
	Complete(context.Context, completepasswordreset.Input) error
}

func NewHandler(completer Completer) http.Handler {
	return http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		if request.Method != http.MethodPost {
			writer.WriteHeader(http.StatusMethodNotAllowed)
			return
		}
		var body struct {
			Token    string `json:"token"`
			Password string `json:"password"`
		}
		decoder := json.NewDecoder(http.MaxBytesReader(writer, request.Body, 8<<10))
		decoder.DisallowUnknownFields()
		if err := decoder.Decode(&body); err != nil {
			writeError(writer, request, http.StatusBadRequest, "VALIDATION_FAILED", "Некорректные данные сброса пароля")
			return
		}
		if err := completer.Complete(request.Context(), completepasswordreset.Input{Token: body.Token, Password: body.Password}); err != nil {
			if passwordapi.WriteBusy(writer, request, err) {
				return
			}
			if errors.Is(err, completepasswordreset.ErrInvalidOrExpired) {
				writeError(writer, request, http.StatusBadRequest, "VALIDATION_FAILED", "Некорректные данные сброса пароля")
				return
			}
			writeError(writer, request, http.StatusInternalServerError, "INTERNAL", "Не удалось сбросить пароль")
			return
		}
		writer.WriteHeader(http.StatusNoContent)
	})
}

func writeError(writer http.ResponseWriter, request *http.Request, status int, code, message string) {
	writer.Header().Set("Content-Type", "application/json; charset=utf-8")
	writer.WriteHeader(status)
	_ = json.NewEncoder(writer).Encode(map[string]any{"error": map[string]string{
		"code":       code,
		"message":    message,
		"request_id": requestid.From(request.Context()),
	}})
}
