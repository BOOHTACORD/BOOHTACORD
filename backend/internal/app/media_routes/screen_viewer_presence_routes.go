package mediaroutes

import (
	"net/http"

	"github.com/jackc/pgx/v5/pgxpool"
	screenviewerpresenceapp "voice-platform/backend/internal/app/media_routes/screen_viewer_presence"
	session "voice-platform/backend/internal/identity/authenticate_session"
	presencememory "voice-platform/backend/internal/media/screen_viewer_presence/memory"
	eventhub "voice-platform/backend/internal/realtime/event_hub"
)

func ConfigureScreenViewerPresenceRoutes(mux *http.ServeMux, database *pgxpool.Pool, sessions session.Service, privateURL, apiKey, apiSecret string, store *presencememory.Store, events *eventhub.Hub) error {
	return screenviewerpresenceapp.ConfigureRoutes(mux, database, sessions, privateURL, apiKey, apiSecret, store, events)
}
