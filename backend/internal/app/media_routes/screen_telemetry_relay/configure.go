package screentelemetryrelayapp

import (
	"fmt"
	"net/http"

	"github.com/jackc/pgx/v5/pgxpool"
	session "voice-platform/backend/internal/identity/authenticate_session"
	screenpreviewlivekit "voice-platform/backend/internal/media/screen_preview/livekit"
	relay "voice-platform/backend/internal/media/screen_telemetry_relay"
	relayapi "voice-platform/backend/internal/media/screen_telemetry_relay/api"
	relaymemory "voice-platform/backend/internal/media/screen_telemetry_relay/memory"
	presencememory "voice-platform/backend/internal/media/screen_viewer_presence/memory"
	presencepostgres "voice-platform/backend/internal/media/screen_viewer_presence/postgres"
	"voice-platform/backend/internal/realtime/event_hub"
)

func ConfigureRoutes(mux *http.ServeMux, database *pgxpool.Pool, sessions session.Service, privateURL, apiKey, apiSecret string, viewers *presencememory.Store, events *eventhub.Hub) error {
	publicationVerifier, err := screenpreviewlivekit.New(screenpreviewlivekit.Config{URL: privateURL, APIKey: apiKey, APISecret: apiSecret})
	if err != nil {
		return fmt.Errorf("configure screen telemetry publication verifier: %w", err)
	}
	authorizer := presencepostgres.New(presencepostgres.NewPoolDatabase(database))
	service, err := relay.New(relay.Dependencies{
		Authority:    authorizer,
		Publications: publicationVerifier,
		Watchers:     viewers,
		Audience:     authorizer,
		Sequences:    relaymemory.NewGate(nil),
		Publisher:    events,
	})
	if err != nil {
		return fmt.Errorf("configure screen telemetry relay: %w", err)
	}
	relayapi.RegisterRoutes(mux, sessions, service)
	return nil
}
