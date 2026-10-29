package mediaroutes

import (
	"net/http"

	"github.com/jackc/pgx/v5/pgxpool"
	screenpreviewapp "voice-platform/backend/internal/app/media_routes/screen_preview"
	session "voice-platform/backend/internal/identity/authenticate_session"
	screenpreview "voice-platform/backend/internal/media/screen_preview"
	eventhub "voice-platform/backend/internal/realtime/event_hub"
)

func ConfigureScreenPreviewRoutes(mux *http.ServeMux, database *pgxpool.Pool, sessions session.Service, privateURL, apiKey, apiSecret, previewRoot string, store screenpreview.Store, events *eventhub.Hub) (screenpreview.Service, error) {
	return screenpreviewapp.ConfigureRoutes(mux, database, sessions, privateURL, apiKey, apiSecret, previewRoot, store, events)
}
