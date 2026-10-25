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
	list "voice-platform/backend/internal/notifications/list_devices"
	d "voice-platform/backend/internal/notifications/register_device"
	deviceapi "voice-platform/backend/internal/notifications/register_device/api"
	store "voice-platform/backend/internal/notifications/register_device/postgres"
	revoke "voice-platform/backend/internal/notifications/revoke_device"
	rate "voice-platform/backend/internal/security/rate_limit"
)

func RegisterDevices(mux *http.ServeMux, database *pgxpool.Pool, sessions auth.Service, c config.Config) {
	feature := deviceConfiguration(database, c)
	limiter, _ := rate.New(rate.Config{Limit: 30, Window: time.Minute, MaxSources: 1024})
	signingPublic := ""
	if len(feature.signing) == ed25519.PrivateKeySize {
		signingPublic = base64.RawURLEncoding.EncodeToString(feature.signing.Public().(ed25519.PublicKey))
	}
	capabilities := map[string]any{"version": 1, "operator_enabled": c.NotificationsAvailable, "registration_available": feature.webReady || feature.mobileReady, "web_push_available": feature.webReady, "mobile_relay_available": feature.mobileReady, "relay_origin": c.Notifications.RelayOrigin, "relay_public_key": c.Notifications.RelayPublicKey, "installation_id": feature.installation, "origin": c.PublicOrigin, "installation_signing_public_key": signingPublic, "vapid_public_key": c.Notifications.VAPIDPublicKey, "namespace": c.Notifications.Namespace, "device_limit": 10}
	var gate d.EndpointValidator
	if feature.gate != nil {
		gate = feature.gate
	}
	service := d.New(store.New(database), feature.box, gate, d.Config{Enabled: c.NotificationsAvailable, Origin: c.PublicOrigin, InstallationID: feature.installation, Namespace: c.Notifications.Namespace, MobileReady: feature.mobileReady})
	handler := sessionapi.Require(sessions)(deviceapi.Handler{Register: service, List: list.New(database, c.PublicOrigin, feature.installation), Revoke: revoke.New(database, c.PublicOrigin, feature.installation), Capabilities: capabilities, Limiter: limiter, Ready: feature.installation != ""})
	mux.Handle("GET /api/v1/notification-devices/capabilities", handler)
	mux.Handle("GET /api/v1/notification-devices", handler)
	mux.Handle("POST /api/v1/notification-devices", handler)
	mux.Handle("PUT /api/v1/notification-devices/{deviceID}", handler)
	mux.Handle("DELETE /api/v1/notification-devices/{deviceID}", handler)
}
