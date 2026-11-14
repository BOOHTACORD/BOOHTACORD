package voicedearenroutes

import (
	"fmt"
	"net/http"

	"github.com/jackc/pgx/v5/pgxpool"
	session "voice-platform/backend/internal/identity/authenticate_session"
	deafenapi "voice-platform/backend/internal/media/set_voice_deafen/api"
	deafenlivekit "voice-platform/backend/internal/media/set_voice_deafen/livekit"
	deafenpostgres "voice-platform/backend/internal/media/set_voice_deafen/postgres"
)

func ConfigureRoutes(mux *http.ServeMux, database *pgxpool.Pool, sessions session.Service, origin, privateURL, apiKey, apiSecret string) error {
	writer, err := deafenlivekit.New(deafenlivekit.Config{URL: privateURL, APIKey: apiKey, APISecret: apiSecret})
	if err != nil {
		return fmt.Errorf("configure voice deafen publisher: %w", err)
	}
	deafenapi.RegisterRoutes(mux, sessions, deafenpostgres.New(deafenpostgres.NewPoolDatabase(database), writer), origin)
	return nil
}
