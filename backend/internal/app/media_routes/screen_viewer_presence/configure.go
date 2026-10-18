package screenviewerpresenceapp

import (
	"fmt"
	"net/http"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	session "voice-platform/backend/internal/identity/authenticate_session"
	screenpreviewlivekit "voice-platform/backend/internal/media/screen_preview/livekit"
	presence "voice-platform/backend/internal/media/screen_viewer_presence"
	presenceapi "voice-platform/backend/internal/media/screen_viewer_presence/api"
	presencememory "voice-platform/backend/internal/media/screen_viewer_presence/memory"
	presencepostgres "voice-platform/backend/internal/media/screen_viewer_presence/postgres"
	eventhub "voice-platform/backend/internal/realtime/event_hub"
)

func ConfigureRoutes(mux *http.ServeMux, database *pgxpool.Pool, sessions session.Service, privateURL, apiKey, apiSecret string, store *presencememory.Store, events *eventhub.Hub) error {
	publications, err := screenpreviewlivekit.New(screenpreviewlivekit.Config{URL: privateURL, APIKey: apiKey, APISecret: apiSecret})
	if err != nil {
		return fmt.Errorf("configure screen viewer publication authority: %w", err)
	}
	service, err := presence.New(presencepostgres.New(presencepostgres.NewPoolDatabase(database)), publications, store, NewHints(events))
	if err != nil {
		return fmt.Errorf("configure screen viewer presence: %w", err)
	}
	presenceapi.RegisterRoutes(mux, sessions, service)
	return nil
}

func NewHints(events *eventhub.Hub) presence.HintPublisher { return viewerHints{events: events} }

type viewerHints struct{ events *eventhub.Hub }

func (hints viewerHints) Changed(ownerAccountID string) {
	if hints.events == nil || ownerAccountID == "" {
		return
	}
	hints.events.PublishToAccountsTransient([]string{ownerAccountID}, eventhub.Event{
		EventID: uuid.NewString(), Kind: "screen_viewers.changed", OccurredAt: time.Now().UTC(), Payload: map[string]any{},
	})
}
