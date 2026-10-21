package logoutapi

import (
	"context"
	"net/http"

	"voice-platform/backend/internal/identity/session"
)

type Logouter interface {
	Logout(context.Context, string) error
}

func NewHandler(logouter Logouter) http.Handler {
	return http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		if request.Method != http.MethodPost {
			writer.WriteHeader(http.StatusMethodNotAllowed)
			return
		}

		cookie, err := request.Cookie(session.CookieName)
		if err == nil {
			if err := logouter.Logout(request.Context(), cookie.Value); err != nil {
				writer.WriteHeader(http.StatusInternalServerError)
				return
			}
		}

		session.ClearCookie(writer)
		writer.WriteHeader(http.StatusNoContent)
	})
}
