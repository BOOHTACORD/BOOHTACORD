package relaysender

import (
	"context"
	"crypto/ed25519"
	"crypto/rand"
	"encoding/base64"
	"encoding/json"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	"testing"
	"time"
	delivery "voice-platform/backend/internal/notifications/dispatch_delivery"
	accept "voice-platform/backend/internal/pushrelay/accept_notification"
	receipt "voice-platform/backend/internal/pushrelay/grant_receipt"
	api "voice-platform/backend/internal/pushrelay/http_api"
	pair "voice-platform/backend/internal/pushrelay/pair_installation"
	fixture "voice-platform/backend/internal/pushrelay/test_scenario"
)

func paired(t *testing.T) (*pgxpool.Pool, Sender, delivery.Message, api.Handler) {
	t.Helper()
	now := time.Now().UTC().Truncate(time.Microsecond)
	pool := fixture.New(t)
	device, key := fixture.Enroll(t, pool, now)
	installPublic, installKey, _ := ed25519.GenerateKey(rand.Reader)
	relayPublic, relayKey, _ := ed25519.GenerateKey(rand.Reader)
	in := pair.Input{Origin: "https://guild.example.invalid", InstallationID: uuid.NewString(), InstallationPublicKey: base64.RawURLEncoding.EncodeToString(installPublic), BindingID: uuid.NewString(), Generation: 1, Namespace: "staging", Nonce: base64.RawURLEncoding.EncodeToString(make([]byte, 32))}
	service := pair.Service{Database: pool, SigningKey: relayKey, Namespace: "staging"}
	signed, err := service.Pair(context.Background(), fixture.Signed(t, key, "device", device, "POST", "/v1/grants", in, now), in, now)
	if err != nil {
		t.Fatal(err)
	}
	if _, err = receipt.Verify(relayPublic, signed, now); err != nil {
		t.Fatal(err)
	}
	sender, err := New(Config{Origin: "https://relay.example.invalid", Namespace: "staging", InstallationID: in.InstallationID, ServerOrigin: in.Origin, InstallationPrivateKey: installKey, RelayPublicKey: relayPublic})
	if err != nil {
		t.Fatal(err)
	}
	secret, _ := json.Marshal(signed)
	message := delivery.Message{Payload: delivery.Payload{Version: 1, Generation: 1, BindingRef: in.BindingID, NotificationRef: uuid.NewString(), GroupRef: uuid.NewString(), Template: "direct_message", ExpiresAt: now.Add(time.Minute)}, Secret: secret, OccurredAt: now}
	return pool, sender, message, api.Handler{Ready: true, Accept: accept.Service{Database: pool, Box: fixture.Box(t), Namespace: "staging"}}
}
