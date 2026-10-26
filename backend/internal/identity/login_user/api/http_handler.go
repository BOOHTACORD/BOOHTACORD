package loginapi

import (
	"context"
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"time"
	admitlogin "voice-platform/backend/internal/identity/admit_login"
	passwordapi "voice-platform/backend/internal/identity/password/api"

	"voice-platform/backend/internal/identity/login_user"
	"voice-platform/backend/internal/identity/session"
	ratelimit "voice-platform/backend/internal/security/rate_limit"
	"voice-platform/backend/internal/security/request_id"
)

type Loginer interface {
	Login(context.Context, loginuser.Input) (loginuser.Result, error)
}

func NewHandler(loginer Loginer) http.Handler {
	return NewHandlerWithAdmission(loginer, nil)
}

func NewHandlerWithAdmission(loginer Loginer, budget *admitlogin.Budget) http.Handler {
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
			writeError(writer, request, http.StatusBadRequest, "VALIDATION_FAILED", "Некорректные данные входа")
			return
		}

		if err := decoder.Decode(&struct{}{}); err != io.EOF {
			writeError(writer, request, http.StatusBadRequest, "VALIDATION_FAILED", "Некорректные данные входа")
			return
		}
		result, retry, err := admittedLogin(request.Context(), loginuser.Input{Login: body.Login, Password: body.Password}, loginer, budget)
		if errors.Is(err, admitlogin.ErrLimited) || errors.Is(err, admitlogin.ErrSaturated) {
			writer.Header().Set("Cache-Control", "no-store")
			ratelimit.WriteLimited(writer, request, retry)
			return
		}
		if passwordapi.WriteBusy(writer, request, err) {
			return
		}
		if errors.Is(err, loginuser.ErrInvalidCredentials) {
			writeError(writer, request, http.StatusUnauthorized, "UNAUTHENTICATED", "Неверный логин или пароль")
			return
		}
		if errors.Is(err, loginuser.ErrBlocked) {
			writeError(writer, request, http.StatusForbidden, "ACCOUNT_BLOCKED", "Аккаунт заблокирован")
			return
		}
		if err != nil {
			writeError(writer, request, http.StatusInternalServerError, "INTERNAL", "Не удалось выполнить вход")
			return
		}
		if result.Token == "" || !result.ExpiresAt.After(time.Now()) {
			writeError(writer, request, http.StatusInternalServerError, "INTERNAL", "Не удалось выполнить вход")
			return
		}

		session.SetCookie(writer, result.Token, result.ExpiresAt)
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
