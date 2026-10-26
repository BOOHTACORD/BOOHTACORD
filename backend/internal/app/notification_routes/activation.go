package notificationroutes

import (
	"crypto/ed25519"
	"encoding/base64"
	"github.com/jackc/pgx/v5/pgxpool"
	"net/http"
	"time"
	config "voice-platform/backend/internal/config/runtime"
	auth "voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	activate "voice-platform/backend/internal/notifications/activate_device"
	api "voice-platform/backend/internal/notifications/activate_device/api"
	reader "voice-platform/backend/internal/notifications/read_delivery_context"
	rate "voice-platform/backend/internal/security/rate_limit"
)

func RegisterActivation(mux *http.ServeMux, database *pgxpool.Pool, sessions auth.Service, c config.Config) {
	feature := deviceConfiguration(database, c)
	public := ""
	if len(feature.signing) == ed25519.PrivateKeySize {
		public = base64.RawURLEncoding.EncodeToString(feature.signing.Public().(ed25519.PublicKey))
	}
	relay, _ := base64.RawURLEncoding.Strict().DecodeString(c.Notifications.RelayPublicKey)
	limiter, _ := rate.New(rate.Config{Limit: 30, Window: time.Minute, MaxSources: 1024})
	handler := api.Handler{Ready: feature.mobileReady, Limiter: limiter, Service: activate.Service{Database: database, Box: feature.box, Scope: reader.Scope{Origin: c.PublicOrigin, InstallationID: feature.installation, Namespace: c.Notifications.Namespace}, RelayPublicKey: ed25519.PublicKey(relay), InstallationPublicKey: public}}
	mux.Handle("POST /api/v1/notification-devices/{deviceID}/activate", sessionapi.Require(sessions)(handler))
}
