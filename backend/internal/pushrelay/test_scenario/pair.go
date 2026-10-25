package relayfixture

import (
	"context"
	"crypto/ed25519"
	"crypto/rand"
	"encoding/base64"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	"testing"
	"time"
	receipt "voice-platform/backend/internal/pushrelay/grant_receipt"
	pair "voice-platform/backend/internal/pushrelay/pair_installation"
)

func Pair(t testing.TB, pool *pgxpool.Pool, now time.Time) (receipt.Grant, ed25519.PrivateKey) {
	t.Helper()
	device, deviceKey := Enroll(t, pool, now)
	public, private, _ := ed25519.GenerateKey(rand.Reader)
	relayPublic, relayKey, _ := ed25519.GenerateKey(rand.Reader)
	input := pair.Input{Origin: "https://guild.example.invalid", InstallationID: uuid.NewString(), InstallationPublicKey: base64.RawURLEncoding.EncodeToString(public), BindingID: uuid.NewString(), Generation: 1, Namespace: "staging", Nonce: base64.RawURLEncoding.EncodeToString(make([]byte, 32))}
	service := pair.Service{Database: pool, SigningKey: relayKey, Namespace: "staging"}
	signed, err := service.Pair(context.Background(), Signed(t, deviceKey, "device", device, "POST", "/v1/grants", input, now), input, now)
	if err != nil {
		t.Fatal(err)
	}
	grant, err := receipt.Verify(relayPublic, signed, now)
	if err != nil {
		t.Fatal(err)
	}
	return grant, private
}
