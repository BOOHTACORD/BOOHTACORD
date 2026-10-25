package notificationroutes

import (
	"crypto/ed25519"
	"encoding/base64"
	config "voice-platform/backend/internal/config/runtime"
	sender "voice-platform/backend/internal/notifications/relay_sender"
)

func mobileConfigured(feature deviceFeature, c config.Config) bool {
	public, err := base64.RawURLEncoding.Strict().DecodeString(c.Notifications.RelayPublicKey)
	if err != nil || feature.box == nil {
		return false
	}
	_, err = sender.New(sender.Config{Origin: c.Notifications.RelayOrigin, Namespace: c.Notifications.Namespace, InstallationID: feature.installation, ServerOrigin: c.PublicOrigin, InstallationPrivateKey: feature.signing, RelayPublicKey: ed25519.PublicKey(public)})
	return err == nil
}
