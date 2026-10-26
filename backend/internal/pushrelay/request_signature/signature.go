package requestsignature

import (
	"crypto/ed25519"
	"encoding/base64"
	"time"
)

const sigLen = 64

const tolerance = 60 * time.Second

// Sign computes an Ed25519 signature over the canonical form.
func Sign(key ed25519.PrivateKey, r Request) (string, error) {
	if len(key) != ed25519.PrivateKeySize {
		return "", ErrInvalid
	}
	c, err := Canonical(r)
	if err != nil {
		return "", err
	}
	sig := ed25519.Sign(key, c)
	return base64.RawURLEncoding.EncodeToString(sig), nil
}

// Verify checks the signature and timestamp tolerance. Callers must persist
// subject/nonce atomically before mutation; this does not prevent replay.
func Verify(pub ed25519.PublicKey, r Request, now time.Time) error {
	if len(pub) != ed25519.PublicKeySize {
		return ErrInvalid
	}
	if len(r.Signature) > maxField {
		return ErrInvalid
	}
	sig, err := base64.RawURLEncoding.Strict().DecodeString(r.Signature)
	if err != nil || len(sig) != sigLen {
		return ErrInvalid
	}
	c, err := Canonical(r)
	if err != nil {
		return err
	}
	if !ed25519.Verify(pub, c, sig) {
		return ErrInvalid
	}
	ts, err := canonicalTimestamp(r.Timestamp)
	if err != nil {
		return err
	}
	t, _ := time.Parse(time.RFC3339, ts)
	if d := now.Sub(t); d < -tolerance || d > tolerance {
		return ErrInvalid
	}
	return nil
}
