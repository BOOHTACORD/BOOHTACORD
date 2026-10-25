package registerdevice

import (
	"crypto/sha256"
	"encoding/base64"
)

// A public scope comparison value, never an authentication credential.
func SessionReference(digest [sha256.Size]byte) string {
	hash := sha256.Sum256(append([]byte("notification-session/v1\x00"), digest[:]...))
	return base64.RawURLEncoding.EncodeToString(hash[:])
}
