package mediaroutes

import (
	"net/http"

	"github.com/jackc/pgx/v5/pgxpool"
	voicedeafenapp "voice-platform/backend/internal/app/media_routes/voice_deafen"
	session "voice-platform/backend/internal/identity/authenticate_session"
)

func ConfigureVoiceDeafenRoutes(mux *http.ServeMux, database *pgxpool.Pool, sessions session.Service, origin, privateURL, apiKey, apiSecret string) error {
	return voicedeafenapp.ConfigureRoutes(mux, database, sessions, origin, privateURL, apiKey, apiSecret)
}
