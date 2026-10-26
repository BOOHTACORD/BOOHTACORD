package notificationroutes

import (
	"context"
	"crypto/ed25519"
	"encoding/base64"
	"github.com/jackc/pgx/v5/pgxpool"
	"time"
	config "voice-platform/backend/internal/config/runtime"
	keys "voice-platform/backend/internal/notifications/load_keys"
	"voice-platform/backend/internal/notifications/secretbox"
	webpush "voice-platform/backend/internal/notifications/web_push"
	"voice-platform/backend/internal/observability/installation"
)

type deviceFeature struct {
	box          *secretbox.Box
	gate         *webpush.Gate
	installation string
	signing      ed25519.PrivateKey
	vapidPrivate string
	webReady     bool
	mobileReady  bool
}

func deviceConfiguration(database *pgxpool.Pool, c config.Config) deviceFeature {
	feature := deviceFeature{}
	if database == nil {
		return feature
	}
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()
	identity, err := installation.Load(ctx, database)
	if err != nil {
		return feature
	}
	feature.installation = identity.ID
	if !c.NotificationsAvailable {
		return feature
	}
	if c.Notifications.Namespace != "production" && c.Notifications.Namespace != "staging" {
		return feature
	}
	key, err := keys.Load32(c.Notifications.SecretKeyFile)
	if err != nil {
		return feature
	}
	feature.box, err = secretbox.New(key)
	if err != nil {
		return feature
	}
	if seed, err := keys.Load32(c.Notifications.SigningKeyFile); err == nil {
		feature.signing = ed25519.NewKeyFromSeed(seed)
	}
	feature.mobileReady = mobileConfigured(feature, c)
	if !c.Notifications.WebEnabled {
		return feature
	}
	gate, err := webpush.NewGate(c.Notifications.WebPushHosts, nil)
	if err != nil {
		return feature
	}
	private, err := keys.Load32(c.Notifications.VAPIDPrivateKeyFile)
	if err != nil {
		return feature
	}
	feature.vapidPrivate = base64.RawURLEncoding.EncodeToString(private)
	if webpush.ValidateVAPID(c.Notifications.VAPIDPublicKey, feature.vapidPrivate, c.Notifications.VAPIDContact) != nil {
		return feature
	}
	feature.gate = &gate
	feature.webReady = true
	return feature
}
