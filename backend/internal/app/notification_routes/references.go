package notificationroutes

import (
	"github.com/jackc/pgx/v5/pgxpool"
	"net/http"
	"time"
	config "voice-platform/backend/internal/config/runtime"
	auth "voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	"voice-platform/backend/internal/notifications/attention"
	reader "voice-platform/backend/internal/notifications/read_delivery_context"
	resolve "voice-platform/backend/internal/notifications/resolve_reference"
	api "voice-platform/backend/internal/notifications/resolve_reference/api"
	rate "voice-platform/backend/internal/security/rate_limit"
)

func RegisterReferences(mux *http.ServeMux, database *pgxpool.Pool, sessions auth.Service, c config.Config) {
	feature := deviceConfiguration(database, c)
	limiter, _ := rate.New(rate.Config{Limit: 120, Window: time.Minute, MaxSources: 1024})
	scope := reader.Scope{Origin: c.PublicOrigin, InstallationID: feature.installation, Namespace: c.Notifications.Namespace}
	handler := sessionapi.Require(sessions)(api.Handler{Resolve: resolve.New(database, scope), Attention: attention.New(database), Limiter: limiter})
	mux.Handle("POST /api/v1/notification-references/resolve", handler)
	mux.Handle("POST /api/v1/notification-references/presented", handler)
	mux.Handle("PUT /api/v1/notification-attention", handler)
}
