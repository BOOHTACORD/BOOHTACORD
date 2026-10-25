package relaysender

import (
	"crypto/ed25519"
	"errors"
	"net/http"
	"net/url"
	webpush "voice-platform/backend/internal/notifications/web_push"
	receipt "voice-platform/backend/internal/pushrelay/grant_receipt"
)

var ErrConfiguration = errors.New("notification relay unavailable")

type Config struct {
	Origin, Namespace, InstallationID, ServerOrigin string
	InstallationPrivateKey                          ed25519.PrivateKey
	RelayPublicKey                                  ed25519.PublicKey
}
type httpClient interface {
	Do(*http.Request) (*http.Response, error)
}
type Sender struct {
	config Config
	client httpClient
}

func New(c Config) (Sender, error) {
	u, err := url.Parse(c.Origin)
	if err != nil || u.Scheme != "https" || u.Host == "" || u.User != nil || u.Path != "" || u.RawQuery != "" || u.Fragment != "" || u.Port() != "" && u.Port() != "443" || len(c.Origin) > 2048 {
		return Sender{}, ErrConfiguration
	}
	if len(c.InstallationPrivateKey) != ed25519.PrivateKeySize || len(c.RelayPublicKey) != ed25519.PublicKeySize || !receipt.ID(c.InstallationID) || (c.Namespace != "staging" && c.Namespace != "production") {
		return Sender{}, ErrConfiguration
	}
	gate, err := webpush.NewGate([]string{u.Hostname()}, nil)
	if err != nil {
		return Sender{}, ErrConfiguration
	}
	return Sender{config: c, client: webpush.NewHTTPClient(gate)}, nil
}
