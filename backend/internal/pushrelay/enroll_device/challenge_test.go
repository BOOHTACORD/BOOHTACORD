package enrolldevice_test

import (
	"context"
	"crypto/ed25519"
	"crypto/rand"
	"encoding/base64"
	"errors"
	"testing"
	"time"
	auth "voice-platform/backend/internal/pushrelay/authorize_request"
	enroll "voice-platform/backend/internal/pushrelay/enroll_device"
	fixture "voice-platform/backend/internal/pushrelay/test_scenario"
)

func TestEnrollmentRequiresReceivedChallengeAndPinnedDeviceKey(t *testing.T) {
	ctx := context.Background()
	pool := fixture.New(t)
	now := time.Now().UTC()
	pub, priv, _ := ed25519.GenerateKey(rand.Reader)
	service := enroll.Service{Database: pool, Box: fixture.Box(t), Namespace: "staging"}
	input := enroll.Challenge{TargetKind: "fcm_token", Target: "synthetic-provider-token-for-owned-device", PublicKey: base64.RawURLEncoding.EncodeToString(pub), Platform: "android", Namespace: "staging"}
	out, err := service.Challenge(ctx, input, "127.0.0.1", now)
	if err != nil || out.State != "pending" {
		t.Fatal(out, err)
	}
	retry, err := service.Challenge(ctx, input, "127.0.0.1", now)
	if err != nil || retry.DeviceID != out.DeviceID {
		t.Fatal("duplicate challenge", retry, err)
	}
	otherPub, attacker, _ := ed25519.GenerateKey(rand.Reader)
	forged := input
	forged.PublicKey = base64.RawURLEncoding.EncodeToString(otherPub)
	if _, err = service.Challenge(ctx, forged, "127.0.0.1", now); !errors.Is(err, enroll.ErrConflict) {
		t.Fatal("token spoof overwrote destination", err)
	}
	proof := fixture.Proof(t, pool, out.DeviceID)
	bad := fixture.Signed(t, attacker, "device", out.DeviceID, "POST", "/v1/devices/verify", proof, now)
	if _, err = service.Verify(ctx, bad, proof, now); !errors.Is(err, auth.ErrDenied) {
		t.Fatal("unowned key accepted", err)
	}
	unknown := proof
	unknown.Nonce = base64.RawURLEncoding.EncodeToString(make([]byte, 32))
	bad = fixture.Signed(t, priv, "device", out.DeviceID, "POST", "/v1/devices/verify", unknown, now)
	if _, err = service.Verify(ctx, bad, unknown, now); !errors.Is(err, auth.ErrDenied) {
		t.Fatal("unreceived proof accepted", err)
	}
	good := fixture.Signed(t, priv, "device", out.DeviceID, "POST", "/v1/devices/verify", proof, now)
	if active, err := service.Verify(ctx, good, proof, now); err != nil || active.State != "active" {
		t.Fatal(active, err)
	}
	if _, err = service.Verify(ctx, good, proof, now); !errors.Is(err, auth.ErrDenied) {
		t.Fatal("signed request replayed", err)
	}
	var count int
	if err = pool.QueryRow(ctx, `SELECT count(*) FROM relay_jobs`).Scan(&count); err != nil || count != 1 {
		t.Fatal("challenge retry duplicated push", count, err)
	}
	var ciphertext []byte
	if err = pool.QueryRow(ctx, `SELECT token_cipher FROM relay_devices WHERE id=$1`, out.DeviceID).Scan(&ciphertext); err != nil || string(ciphertext) == input.Target {
		t.Fatal("token stored raw", err)
	}
}
