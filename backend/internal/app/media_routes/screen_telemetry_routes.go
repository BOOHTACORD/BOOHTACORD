package mediaroutes

import (
	"net/http"

	"github.com/jackc/pgx/v5/pgxpool"
	screenTelemetryApp "voice-platform/backend/internal/app/media_routes/screen_telemetry_relay"
	session "voice-platform/backend/internal/identity/authenticate_session"
	presencememory "voice-platform/backend/internal/media/screen_viewer_presence/memory"
	eventhub "voice-platform/backend/internal/realtime/event_hub"
)

func ConfigureScreenTelemetryRoutes(mux *http.ServeMux, database *pgxpool.Pool, sessions session.Service, privateURL, apiKey, apiSecret string, viewers *presencememory.Store, events *eventhub.Hub) error {
	return screenTelemetryApp.ConfigureRoutes(mux, database, sessions, privateURL, apiKey, apiSecret, viewers, events)
}
