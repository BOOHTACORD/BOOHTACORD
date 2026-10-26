package relayfixture

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
	"voice-platform/backend/internal/notifications/secretbox"
	enroll "voice-platform/backend/internal/pushrelay/enroll_device"
	signature "voice-platform/backend/internal/pushrelay/request_signature"
	schema "voice-platform/backend/internal/pushrelay/schema"
	fixture "voice-platform/backend/internal/testsupport/postgres"
)

func New(t testing.TB) *pgxpool.Pool {
	t.Helper()
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	pool := fixture.New(t, ctx, "VOICE_PLATFORM_TEST_DATABASE_URL", fixture.LoopbackIP)
	if err := schema.Migrate(ctx, pool); err != nil {
		t.Fatal(err)
	}
	if err := schema.BindNamespace(ctx, pool, "staging"); err != nil {
		t.Fatal(err)
	}
	return pool
}
func Box(t testing.TB) *secretbox.Box {
	t.Helper()
	box, err := secretbox.New(make([]byte, 32))
	if err != nil {
		t.Fatal(err)
	}
	return box
}
func Signed(t testing.TB, key ed25519.PrivateKey, role, subject, method, path string, body any, now time.Time) signature.Request {
	t.Helper()
	raw, err := json.Marshal(body)
	if err != nil {
		t.Fatal(err)
	}
	r := signature.Request{Method: method, Path: path, Role: role, Subject: subject, Nonce: uuid.NewString(), Timestamp: now.UTC().Truncate(time.Second).Format(time.RFC3339), Body: raw}
	r.Signature, err = signature.Sign(key, r)
	if err != nil {
		t.Fatal(err)
	}
	return r
}
func Proof(t testing.TB, pool *pgxpool.Pool, id string) enroll.Proof {
	t.Helper()
	var job string
	var ciphertext []byte
	if err := pool.QueryRow(context.Background(), `SELECT id::text,payload_cipher FROM relay_jobs WHERE device_id=$1::uuid AND kind='challenge'`, id).Scan(&job, &ciphertext); err != nil {
		t.Fatal(err)
	}
	raw, err := Box(t).Open(ciphertext, enroll.JobScope(job, id, "", "challenge", "staging", id))
	if err != nil {
		t.Fatal(err)
	}
	var proof enroll.Proof
	if json.Unmarshal(raw, &proof) != nil {
		t.Fatal("invalid synthetic provider challenge")
	}
	return proof
}
func Enroll(t testing.TB, pool *pgxpool.Pool, now time.Time) (string, ed25519.PrivateKey) {
	t.Helper()
	pub, priv, err := ed25519.GenerateKey(rand.Reader)
	if err != nil {
		t.Fatal(err)
	}
	service := enroll.Service{Database: pool, Box: Box(t), Namespace: "staging"}
	out, err := service.Challenge(context.Background(), enroll.Challenge{TargetKind: "fcm_token", Target: "synthetic-token-" + uuid.NewString(), PublicKey: base64.RawURLEncoding.EncodeToString(pub), Platform: "android", Namespace: "staging"}, "127.0.0.1", now)
	if err != nil {
		t.Fatal(err)
	}
	proof := Proof(t, pool, out.DeviceID)
	// This fixture models a fake provider accepting and delivering the challenge.
	if _, err = pool.Exec(context.Background(), `WITH accepted AS(UPDATE relay_jobs SET state='accepted_by_provider' WHERE device_id=$1::uuid AND kind='challenge' AND state='pending' RETURNING 1)
 UPDATE relay_policy SET pending=pending-(SELECT count(*)FROM accepted) WHERE singleton`, out.DeviceID); err != nil {
		t.Fatal(err)
	}
	signed := Signed(t, priv, "device", out.DeviceID, "POST", "/v1/devices/verify", proof, now)
	if _, err = service.Verify(context.Background(), signed, proof, now); err != nil {
		t.Fatal(err)
	}
	return out.DeviceID, priv
}
