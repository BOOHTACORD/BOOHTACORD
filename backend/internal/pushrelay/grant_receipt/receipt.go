package grantreceipt

import (
	"bytes"
	"crypto/ed25519"
	"encoding/base64"
	"encoding/json"
	"errors"
	"github.com/google/uuid"
	"io"
	"net/url"
	"time"
)

var ErrInvalid = errors.New("invalid relay grant receipt")

type Grant struct {
	Version               int       `json:"version"`
	GrantID               string    `json:"grant_id"`
	TenantID              string    `json:"tenant_id"`
	Origin                string    `json:"origin"`
	InstallationID        string    `json:"installation_id"`
	InstallationPublicKey string    `json:"installation_public_key"`
	BindingID             string    `json:"binding_id"`
	Generation            int64     `json:"generation"`
	Namespace             string    `json:"namespace"`
	Nonce                 string    `json:"nonce"`
	ExpiresAt             time.Time `json:"expires_at"`
}
type Receipt struct {
	Payload   string `json:"payload"`
	Signature string `json:"signature"`
}

func ID(raw string) bool {
	id, err := uuid.Parse(raw)
	return err == nil && id != uuid.Nil && id.String() == raw
}
func (g Grant) Validate(now time.Time) error {
	u, err := url.Parse(g.Origin)
	if err != nil || u.Scheme != "https" || u.Host == "" || u.User != nil || u.Path != "" || u.RawQuery != "" || u.Fragment != "" || len(g.Origin) > 2048 {
		return ErrInvalid
	}
	if g.Version != 1 || !ID(g.GrantID) || !ID(g.TenantID) || !ID(g.InstallationID) || !ID(g.BindingID) || g.Generation < 1 || g.Generation > 1e9 {
		return ErrInvalid
	}
	if g.Namespace != "staging" && g.Namespace != "production" {
		return ErrInvalid
	}
	for _, value := range []string{g.InstallationPublicKey, g.Nonce} {
		raw, err := base64.RawURLEncoding.Strict().DecodeString(value)
		if err != nil || len(raw) != 32 {
			return ErrInvalid
		}
	}
	_, offset := g.ExpiresAt.Zone()
	if offset != 0 || !g.ExpiresAt.After(now) || g.ExpiresAt.After(now.Add(180*24*time.Hour)) {
		return ErrInvalid
	}
	return nil
}
func Sign(key ed25519.PrivateKey, grant Grant, now time.Time) (Receipt, error) {
	if len(key) != ed25519.PrivateKeySize || grant.Validate(now) != nil {
		return Receipt{}, ErrInvalid
	}
	raw, err := json.Marshal(grant)
	if err != nil {
		return Receipt{}, ErrInvalid
	}
	return Receipt{base64.RawURLEncoding.EncodeToString(raw), base64.RawURLEncoding.EncodeToString(ed25519.Sign(key, append([]byte("notification-relay-grant/v1\x00"), raw...)))}, nil
}
func Verify(key ed25519.PublicKey, receipt Receipt, now time.Time) (Grant, error) {
	var grant Grant
	if len(key) != ed25519.PublicKeySize || len(receipt.Payload) > 8192 || len(receipt.Signature) > 128 {
		return grant, ErrInvalid
	}
	raw, err := base64.RawURLEncoding.Strict().DecodeString(receipt.Payload)
	if err != nil || len(raw) > 6144 {
		return grant, ErrInvalid
	}
	signature, err := base64.RawURLEncoding.Strict().DecodeString(receipt.Signature)
	if err != nil || !ed25519.Verify(key, append([]byte("notification-relay-grant/v1\x00"), raw...), signature) {
		return grant, ErrInvalid
	}
	decoder := json.NewDecoder(bytes.NewReader(raw))
	decoder.DisallowUnknownFields()
	if decoder.Decode(&grant) != nil || decoder.Decode(&struct{}{}) != io.EOF || grant.Validate(now) != nil {
		return Grant{}, ErrInvalid
	}
	return grant, nil
}
