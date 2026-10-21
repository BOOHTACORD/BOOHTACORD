// Package installation owns persistent deployment identity, never account authority.
package installation

import (
	"crypto/ed25519"
	"crypto/hmac"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"errors"
	"github.com/google/uuid"
	"time"
)

type Identity struct {
	LastAccepted *time.Time `json:"-"`
	Enrolled     bool       `json:"-"`
	ID           string     `json:"installation_id"`
	Key          []byte     `json:"-"`
	Seed         []byte     `json:"-"`
	Mode         string     `json:"mode"`
	Endpoint     string     `json:"-"`
	Credential   string     `json:"-"`
}

func New() (Identity, error) {
	key, seed := make([]byte, 32), make([]byte, 32)
	if _, err := rand.Read(key); err != nil {
		return Identity{}, err
	}
	if _, err := rand.Read(seed); err != nil {
		return Identity{}, err
	}
	return Identity{ID: uuid.NewString(), Key: key, Seed: seed, Mode: "local_only"}, nil
}
func (i Identity) Valid() error {
	id, err := uuid.Parse(i.ID)
	if err != nil || id.Version() != 4 || id.String() != i.ID || len(i.Key) != 32 || len(i.Seed) != ed25519.SeedSize || (i.Mode != "local_only" && i.Mode != "central") {
		return errors.New("installation identity unavailable")
	}
	return nil
}
func (i Identity) Pseudonym(domain, value string) string {
	if value == "" || len(i.Key) != 32 {
		return ""
	}
	mac := hmac.New(sha256.New, i.Key)
	mac.Write([]byte("boohtacord/" + domain + "/v1\x00" + value))
	return base64.RawURLEncoding.EncodeToString(mac.Sum(nil))
}
func (i Identity) ProofKey() string               { return i.Pseudonym("causal-signing", i.ID) }
func (i Identity) PrivateKey() ed25519.PrivateKey { return ed25519.NewKeyFromSeed(i.Seed) }
