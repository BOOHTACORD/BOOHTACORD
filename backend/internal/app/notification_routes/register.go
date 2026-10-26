package notificationroutes

import (
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	"net/http"
	"time"
	auth "voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	p "voice-platform/backend/internal/notifications/preferences"
	access "voice-platform/backend/internal/notifications/preferences/access"
	api "voice-platform/backend/internal/notifications/preferences/api"
	store "voice-platform/backend/internal/notifications/preferences/postgres"
	hub "voice-platform/backend/internal/realtime/event_hub"
)

type publisher struct{ events *hub.Hub }

func (p publisher) Changed(actor string, revision int64) {
	if p.events == nil {
		return
	}
	p.events.PublishToAccountsTransient([]string{actor}, hub.Event{EventID: uuid.NewString(), Kind: "notification.preferences_changed", OccurredAt: time.Now().UTC(), Payload: map[string]any{"version": 1, "revision": revision}})
}
func Register(mux *http.ServeMux, database *pgxpool.Pool, sessions auth.Service, available bool, events *hub.Hub) {
	handler := sessionapi.Require(sessions)(api.NewHandler(p.New(store.New(database)), access.New(database), available, publisher{events}))
	mux.Handle("GET /api/v1/notification-preferences", handler)
	mux.Handle("PUT /api/v1/notification-preferences", handler)
	mux.Handle("POST /api/v1/notification-preferences/import", handler)
}
