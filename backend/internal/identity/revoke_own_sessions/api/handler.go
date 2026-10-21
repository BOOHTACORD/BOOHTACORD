package revokesessionapi

import (
	"context"
	"encoding/json"
	"errors"
	"github.com/google/uuid"
	"net/http"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	revoke "voice-platform/backend/internal/identity/revoke_own_sessions"
	"voice-platform/backend/internal/identity/session"
	requestid "voice-platform/backend/internal/security/request_id"
)

type Store interface {
	Revoke(context.Context, revoke.Input) (revoke.Result, error)
}

func New(store Store) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Cache-Control", "no-store")
		principal, ok := sessionapi.PrincipalFrom(r.Context())
		if !ok {
			fail(w, r, 401, "UNAUTHENTICATED", "Требуется вход")
			return
		}
		expected := r.Header.Get("X-Account-ID")
		if expected == "" {
			fail(w, r, 400, "VALIDATION_FAILED", "Укажите аккаунт текущего интерфейса")
			return
		}
		if expected != principal.AccountID {
			fail(w, r, 409, "SESSION_ACCOUNT_CHANGED", "Аккаунт изменился. Обновите страницу.")
			return
		}
		input := revoke.Input{AccountID: principal.AccountID, Current: principal.SessionDigest}
		switch r.Method {
		case http.MethodPost:
			input.Others = true
		case http.MethodDelete:
			input.SessionID = r.PathValue("sessionID")
			if _, err := uuid.Parse(input.SessionID); err != nil {
				fail(w, r, 400, "VALIDATION_FAILED", "Некорректный сеанс")
				return
			}
		default:
			w.WriteHeader(http.StatusMethodNotAllowed)
			return
		}
		result, err := store.Revoke(r.Context(), input)
		if errors.Is(err, revoke.ErrNotFound) {
			fail(w, r, 404, "NOT_FOUND", "Сеанс не найден")
			return
		}
		if errors.Is(err, revoke.ErrUnauthenticated) {
			fail(w, r, 401, "UNAUTHENTICATED", "Требуется вход")
			return
		}
		if err != nil {
			fail(w, r, 500, "INTERNAL", "Не удалось завершить сеанс")
			return
		}
		if result.CurrentRevoked {
			session.ClearCookie(w)
		}
		w.WriteHeader(http.StatusNoContent)
	})
}
func fail(w http.ResponseWriter, r *http.Request, status int, code, message string) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(map[string]any{"error": map[string]string{
		"code": code, "message": message, "request_id": requestid.From(r.Context()),
	}})
}
