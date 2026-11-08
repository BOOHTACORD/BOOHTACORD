package voicesoundroutes

import (
	"net/http"
	session "voice-platform/backend/internal/identity/authenticate_session/api"
	api "voice-platform/backend/internal/voice/sound_preferences/api"
)

func Register(mux *http.ServeMux, service api.Service, authenticator session.Authenticator) {
	h := session.Require(authenticator)(api.NewHandler(service))
	mux.Handle("GET /api/v1/me/voice-sound-preferences", h)
	mux.Handle("PATCH /api/v1/me/voice-sound-preferences", h)
}
