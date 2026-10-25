package registerdevicepostgres

import (
	"context"
	"crypto/sha256"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	"testing"
	"time"
	"voice-platform/backend/internal/database/migrate"
	d "voice-platform/backend/internal/notifications/register_device"
	fixture "voice-platform/backend/internal/testsupport/postgres"
)

const account = "11111111-1111-4111-8111-111111111111"
const other = "22222222-2222-4222-8222-222222222222"

func newPool(t *testing.T) *pgxpool.Pool {
	t.Helper()
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	pool := fixture.New(t, ctx, "VOICE_PLATFORM_TEST_DATABASE_URL", fixture.LoopbackIP)
	if err := migrate.Run(ctx, pool); err != nil {
		t.Fatal(err)
	}
	for i, id := range []string{account, other} {
		if _, err := pool.Exec(ctx, `INSERT INTO users(id,login,display_name,password_hash,role) VALUES($1,$2,'Test','test','MEMBER')`, id, "user"+string(rune('a'+i))); err != nil {
			t.Fatal(err)
		}
	}
	for i := byte(1); i <= 3; i++ {
		owner := account
		if i == 3 {
			owner = other
		}
		digest := [32]byte{i}
		if _, err := pool.Exec(ctx, `INSERT INTO sessions(token_digest,user_id) VALUES($1,$2)`, digest[:], owner); err != nil {
			t.Fatal(err)
		}
	}
	return pool
}
func record() d.Record {
	now := time.Now().UTC()
	id := uuid.NewString()
	return d.Record{ID: id, AccountID: account, SessionDigest: [32]byte{1}, InstallationID: "33333333-3333-4333-8333-333333333333", Origin: "https://chat.example.invalid", InstanceID: uuid.NewString(), Transport: "web_push", Namespace: "staging", Generation: 1, State: "active", Permission: "granted", SecretCipher: make([]byte, 48), Fingerprint: sha256.Sum256([]byte(id)), RegistrationHash: sha256.Sum256([]byte("register/" + id)), ConsentAt: now, CreatedAt: now, UpdatedAt: now, ExpiresAt: now.Add(24 * time.Hour)}
}
