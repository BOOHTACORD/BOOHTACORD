package activatedevice_test

import (
	"context"
	"crypto/ed25519"
	"crypto/rand"
	"encoding/base64"
	"errors"
	"github.com/google/uuid"
	"testing"
	"time"
	activate "voice-platform/backend/internal/notifications/activate_device"
	d "voice-platform/backend/internal/notifications/register_device"
	store "voice-platform/backend/internal/notifications/register_device/postgres"
	revoke "voice-platform/backend/internal/notifications/revoke_device"
	fixture "voice-platform/backend/internal/notifications/test_scenario"
	receipt "voice-platform/backend/internal/pushrelay/grant_receipt"
)

func TestActivationRequiresOwnSessionPinnedRelayAndCurrentNonce(t *testing.T) {
	ctx := context.Background()
	pool := fixture.New(t)
	scope := fixture.Scope(t, pool)
	now := time.Now().UTC()
	installPublic, _, _ := ed25519.GenerateKey(rand.Reader)
	relayPublic, relayKey, _ := ed25519.GenerateKey(rand.Reader)
	installationKey := base64.RawURLEncoding.EncodeToString(installPublic)
	registrar := d.New(store.New(pool), fixture.Box(t), nil, d.Config{Enabled: true, Origin: scope.Origin, InstallationID: scope.InstallationID, Namespace: "staging", MobileReady: true})
	enrollment, err := registrar.Register(ctx, d.Input{AccountID: fixture.Recipient, SessionDigest: [32]byte{2}, InstanceID: uuid.NewString(), Transport: "mobile_relay", Namespace: "staging", Permission: "granted", ConsentVersion: 1})
	if err != nil {
		t.Fatal(err)
	}
	grant := receipt.Grant{Version: 1, GrantID: uuid.NewString(), TenantID: uuid.NewString(), Origin: scope.Origin, InstallationID: scope.InstallationID, InstallationPublicKey: installationKey, BindingID: enrollment.Device.ID, Generation: 1, Namespace: "staging", Nonce: enrollment.Nonce, ExpiresAt: now.Add(30 * 24 * time.Hour)}
	signed, err := receipt.Sign(relayKey, grant, now)
	if err != nil {
		t.Fatal(err)
	}
	service := activate.Service{Database: pool, Box: fixture.Box(t), Scope: scope, RelayPublicKey: relayPublic, InstallationPublicKey: installationKey}
	input := activate.Input{ExpectedGeneration: 1, Receipt: signed}
	if _, err = service.Activate(ctx, fixture.Outsider, [32]byte{3}, enrollment.Device.ID, input, now); !errors.Is(err, activate.ErrNotFound) {
		t.Fatal("admin activated foreign DM device", err)
	}
	if _, err = pool.Exec(ctx, `INSERT INTO sessions(token_digest,user_id)VALUES($1,$2)`, []byte{4, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0}, fixture.Recipient); err != nil {
		t.Fatal(err)
	}
	if _, err = service.Activate(ctx, fixture.Recipient, [32]byte{4}, enrollment.Device.ID, input, now); !errors.Is(err, activate.ErrNotFound) {
		t.Fatal("other issuing session activated device", err)
	}
	active, err := service.Activate(ctx, fixture.Recipient, [32]byte{2}, enrollment.Device.ID, input, now)
	if err != nil || active.State != "active" || active.Generation != 1 {
		t.Fatal(active.State, err)
	}
	retry, err := service.Activate(ctx, fixture.Recipient, [32]byte{2}, enrollment.Device.ID, input, now)
	if err != nil || retry.Generation != active.Generation {
		t.Fatal("activation retry not idempotent", err)
	}
	wrong := grant
	wrong.Nonce = base64.RawURLEncoding.EncodeToString(make([]byte, 32))
	forged, _ := receipt.Sign(relayKey, wrong, now)
	if _, err = service.Activate(ctx, fixture.Recipient, [32]byte{2}, enrollment.Device.ID, activate.Input{ExpectedGeneration: 1, Receipt: forged}, now); !errors.Is(err, d.ErrConflict) {
		t.Fatal("different receipt replaced active grant", err)
	}
	if err = revoke.New(pool, scope.Origin, scope.InstallationID).Revoke(ctx, fixture.Recipient, enrollment.Device.ID, 1); err != nil {
		t.Fatal(err)
	}
	if _, err = service.Activate(ctx, fixture.Recipient, [32]byte{2}, enrollment.Device.ID, input, now); !errors.Is(err, d.ErrConflict) {
		t.Fatal("late activation revived revoked binding", err)
	}
}
