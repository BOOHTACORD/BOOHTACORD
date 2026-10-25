package pairinstallation_test

import (
	"context"
	"crypto/ed25519"
	"crypto/rand"
	"encoding/base64"
	"errors"
	"github.com/google/uuid"
	"testing"
	"time"
	auth "voice-platform/backend/internal/pushrelay/authorize_request"
	receipt "voice-platform/backend/internal/pushrelay/grant_receipt"
	pair "voice-platform/backend/internal/pushrelay/pair_installation"
	revoke "voice-platform/backend/internal/pushrelay/revoke_grant"
	fixture "voice-platform/backend/internal/pushrelay/test_scenario"
)

func TestPairPinsInstallationAndIndependentRevokeNeedsOwningDevice(t *testing.T) {
	ctx := context.Background()
	pool := fixture.New(t)
	now := time.Now().UTC()
	device, deviceKey := fixture.Enroll(t, pool, now)
	other, otherKey := fixture.Enroll(t, pool, now)
	relayPublic, relayKey, _ := ed25519.GenerateKey(rand.Reader)
	installPublic, _, _ := ed25519.GenerateKey(rand.Reader)
	service := pair.Service{Database: pool, SigningKey: relayKey, Namespace: "staging"}
	input := pair.Input{Origin: "https://guild.example.invalid", InstallationID: uuid.NewString(), InstallationPublicKey: base64.RawURLEncoding.EncodeToString(installPublic), BindingID: uuid.NewString(), Generation: 1, Namespace: "staging", Nonce: base64.RawURLEncoding.EncodeToString(make([]byte, 32))}
	request := fixture.Signed(t, deviceKey, "device", device, "POST", "/v1/grants", input, now)
	signed, err := service.Pair(ctx, request, input, now)
	if err != nil {
		t.Fatal(err)
	}
	grant, err := receipt.Verify(relayPublic, signed, now)
	if err != nil || grant.BindingID != input.BindingID || grant.Origin != input.Origin {
		t.Fatal(grant, err)
	}
	retry := fixture.Signed(t, deviceKey, "device", device, "POST", "/v1/grants", input, now)
	again, err := service.Pair(ctx, retry, input, now)
	if err != nil || again != signed {
		t.Fatal("pair retry not stable", err)
	}
	if _, err = service.Pair(ctx, request, input, now); !errors.Is(err, auth.ErrDenied) {
		t.Fatal("pair signature replay", err)
	}
	newKey, _, _ := ed25519.GenerateKey(rand.Reader)
	clone := input
	clone.InstallationPublicKey = base64.RawURLEncoding.EncodeToString(newKey)
	clone.BindingID = uuid.NewString()
	if _, err = service.Pair(ctx, fixture.Signed(t, deviceKey, "device", device, "POST", "/v1/grants", clone, now), clone, now); !errors.Is(err, pair.ErrConflict) {
		t.Fatal("cloned installation replaced pin", err)
	}
	stolen := input
	stolen.Generation = 2
	if _, err = service.Pair(ctx, fixture.Signed(t, otherKey, "device", other, "POST", "/v1/grants", stolen, now), stolen, now); !errors.Is(err, pair.ErrConflict) {
		t.Fatal("other device replaced binding", err)
	}
	revoker := revoke.Store{Database: pool}
	if err = revoker.Revoke(ctx, fixture.Signed(t, otherKey, "device", other, "DELETE", "/v1/grants/"+grant.GrantID, struct{}{}, now), grant.GrantID, now); !errors.Is(err, revoke.ErrNotFound) {
		t.Fatal("foreign device revoked grant", err)
	}
	if _, err = pool.Exec(ctx, `UPDATE relay_policy SET enabled=false`); err != nil {
		t.Fatal(err)
	}
	if err = revoker.Revoke(ctx, fixture.Signed(t, deviceKey, "device", device, "DELETE", "/v1/grants/"+grant.GrantID, struct{}{}, now), grant.GrantID, now); err != nil {
		t.Fatal("offline-capable revoke blocked by kill", err)
	}
}
