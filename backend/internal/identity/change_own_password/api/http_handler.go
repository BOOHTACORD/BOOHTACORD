package changepasswordapi

import (
	"context"
	"encoding/json"
	"errors"
	"io"
	"net/http"
	passwordapi "voice-platform/backend/internal/identity/password/api"

	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	changeownpassword "voice-platform/backend/internal/identity/change_own_password"
	"voice-platform/backend/internal/security/request_id"
)

type Changer interface {
	Change(context.Context, changeownpassword.Input) error
}

func NewHandler(changer Changer) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		principal, ok := sessionapi.PrincipalFrom(r.Context())
		if !ok {
			writeError(w, r, http.StatusUnauthorized, "UNAUTHENTICATED", "Требуется вход")
			return
		}
		var body struct {
			CurrentPassword string `json:"current_password"`
			NewPassword     string `json:"new_password"`
		}
		decoder := json.NewDecoder(http.MaxBytesReader(w, r.Body, 8<<10))
		decoder.DisallowUnknownFields()
		if err := decoder.Decode(&body); err != nil || decoder.Decode(new(any)) != io.EOF || body.CurrentPassword == "" || body.NewPassword == "" {
			writeError(w, r, http.StatusBadRequest, "VALIDATION_FAILED", "Некорректные данные смены пароля")
			return
		}
		err := changer.Change(r.Context(), changeownpassword.Input{AccountID: principal.AccountID, CurrentPassword: body.CurrentPassword, NewPassword: body.NewPassword, CurrentSessionDigest: principal.SessionDigest})
		if passwordapi.WriteBusy(w, r, err) {
			return
		}
		switch {
		case err == nil:
			w.WriteHeader(http.StatusNoContent)
		case errors.Is(err, changeownpassword.ErrInvalidInput), errors.Is(err, changeownpassword.ErrCurrentPasswordInvalid):
			writeError(w, r, http.StatusBadRequest, "VALIDATION_FAILED", "Не удалось изменить пароль")
		case errors.Is(err, changeownpassword.ErrCredentialChanged):
			writeError(w, r, http.StatusConflict, "CREDENTIAL_CHANGED", "Учётные данные изменились; войдите снова")
		default:
			writeError(w, r, http.StatusInternalServerError, "INTERNAL", "Не удалось изменить пароль")
		}
	})
}

func writeError(w http.ResponseWriter, r *http.Request, status int, code, message string) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(map[string]any{"error": map[string]string{"code": code, "message": message, "request_id": requestid.From(r.Context())}})
}
