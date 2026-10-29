package screenpreviewapp

import (
	"fmt"
	"net/http"

	"github.com/jackc/pgx/v5/pgxpool"
	session "voice-platform/backend/internal/identity/authenticate_session"
	screenpreview "voice-platform/backend/internal/media/screen_preview"
	screenpreviewapi "voice-platform/backend/internal/media/screen_preview/api"
	screenpreviewlivekit "voice-platform/backend/internal/media/screen_preview/livekit"
	screenpreviewpostgres "voice-platform/backend/internal/media/screen_preview/postgres"
	eventhub "voice-platform/backend/internal/realtime/event_hub"
)

func ConfigureRoutes(mux *http.ServeMux, database *pgxpool.Pool, sessions session.Service, privateURL, apiKey, apiSecret, previewRoot string, store screenpreview.Store, events *eventhub.Hub) (screenpreview.Service, error) {
	publications, err := screenpreviewlivekit.New(screenpreviewlivekit.Config{URL: privateURL, APIKey: apiKey, APISecret: apiSecret})
	if err != nil {
		return screenpreview.Service{}, fmt.Errorf("configure screen preview publication authority: %w", err)
	}
	capturer, err := screenpreviewlivekit.NewCapturer(screenpreviewlivekit.Config{URL: privateURL, APIKey: apiKey, APISecret: apiSecret, PreviewRoot: previewRoot})
	if err != nil {
		return screenpreview.Service{}, fmt.Errorf("configure private screen preview Egress: %w", err)
	}
	authorizer := screenpreviewpostgres.New(screenpreviewpostgres.NewPoolDatabase(database))
	service, err := screenpreview.New(authorizer, publications, store, capturer, screenPreviewHints{authorizer: authorizer, events: events})
	if err != nil {
		return screenpreview.Service{}, fmt.Errorf("configure screen preview service: %w", err)
	}
	screenpreviewapi.RegisterRoutes(mux, sessions, service)
	return service, nil
}
