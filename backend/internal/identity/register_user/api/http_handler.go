package registerapi

import (
	"context"
	"crypto/sha256"
	"encoding/json"
	"errors"
	"go.opentelemetry.io/otel/trace"
	"net/http"
	passwordapi "voice-platform/backend/internal/identity/password/api"
	correlatesession "voice-platform/backend/internal/observability/correlate_session"

	"voice-platform/backend/internal/identity/register_user"
	"voice-platform/backend/internal/identity/registration"
	"voice-platform/backend/internal/security/request_id"
)

type Registerer interface {
	Register(context.Context, registeruser.Input) (registeruser.Account, error)
}

func NewHandler(registerer Registerer) http.Handler {
	return http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		if request.Method != http.MethodPost {
			writer.WriteHeader(http.StatusMethodNotAllowed)
			return
		}

		var body struct {
			Login    string `json:"login"`
			Password string `json:"password"`
		}
		decoder := json.NewDecoder(http.MaxBytesReader(writer, request.Body, 8<<10))
		decoder.DisallowUnknownFields()
		if err := decoder.Decode(&body); err != nil {
			writeError(writer, request, http.StatusBadRequest, "VALIDATION_FAILED", "Некорректные данные регистрации")
			return
		}

		account, err := registerer.Register(request.Context(), registeruser.Input{Login: body.Login, Password: body.Password})
		if passwordapi.WriteBusy(writer, request, err) {
			return
		}
		if errors.Is(err, registration.ErrInvalidLogin) || errors.Is(err, registration.ErrInvalidPassword) {
			writeError(writer, request, http.StatusBadRequest, "VALIDATION_FAILED", "Некорректные данные регистрации")
			return
		}
		if errors.Is(err, registeruser.ErrLoginTaken) {
			writeError(writer, request, http.StatusConflict, "CONFLICT", "Этот логин уже занят")
			return
		}
		if errors.Is(err, registeruser.ErrRegistrationUnavailable) {
			writeError(writer, request, http.StatusServiceUnavailable, "REGISTRATION_NOT_READY", "Регистрация откроется после начальной настройки сервера")
			return
		}
		if err != nil {
			writeError(writer, request, http.StatusInternalServerError, "INTERNAL", "Не удалось создать аккаунт")
			return
		}

		trace.SpanFromContext(request.Context()).SetAttributes(correlatesession.NamedAttributes(account.ID, [sha256.Size]byte{}, account.DisplayName)...)
		writeJSON(writer, http.StatusCreated, struct {
			ID          string `json:"id"`
			Login       string `json:"login"`
			DisplayName string `json:"display_name"`
			Role        string `json:"role"`
		}{account.ID, account.Login, account.DisplayName, string(account.Role)})
	})
}

func writeError(writer http.ResponseWriter, request *http.Request, status int, code, message string) {
	writeJSON(writer, status, struct {
		Error struct {
			Code      string `json:"code"`
			Message   string `json:"message"`
			RequestID string `json:"request_id"`
		} `json:"error"`
	}{Error: struct {
		Code      string `json:"code"`
		Message   string `json:"message"`
		RequestID string `json:"request_id"`
	}{code, message, requestid.From(request.Context())}})
}

func writeJSON(writer http.ResponseWriter, status int, value any) {
	writer.Header().Set("Content-Type", "application/json; charset=utf-8")
	writer.WriteHeader(status)
	_ = json.NewEncoder(writer).Encode(value)
}
