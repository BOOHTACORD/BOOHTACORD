package serializesessiondelivery

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/google/uuid"
	"voice-platform/backend/internal/database/migrate"
	auth "voice-platform/backend/internal/identity/authenticate_session"
	"voice-platform/backend/internal/identity/session"
	pgfixture "voice-platform/backend/internal/testsupport/postgres"
)

func TestPostgresGuardRejectsBlockedExpiredAndChangedRole(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
	defer cancel()
	pool := pgfixture.New(t, ctx, "VOICE_PLATFORM_TEST_DATABASE_URL", pgfixture.LoopbackIP)
	if err := migrate.Run(ctx, pool); err != nil {
		t.Fatal(err)
	}
	id := uuid.NewString()
	token, err := session.Issue()
	if err != nil {
		t.Fatal(err)
	}
	if _, err := pool.Exec(ctx, `INSERT INTO users(id,login,display_name,password_hash,role) VALUES($1,'delivery_invalid','Guard','x','MEMBER')`, id); err != nil {
		t.Fatal(err)
	}
	if _, err := pool.Exec(ctx, `INSERT INTO sessions(token_digest,user_id) VALUES($1,$2)`, token.Digest[:], id); err != nil {
		t.Fatal(err)
	}
	guard, err := New(pool, 1, time.Second)
	if err != nil {
		t.Fatal(err)
	}
	principal := auth.Principal{AccountID: id, Role: "MEMBER", SessionDigest: token.Digest}
	deny := func() {
		t.Helper()
		called := false
		err := guard.WithSession(ctx, principal, func(context.Context) error { called = true; return nil })
		if !errors.Is(err, ErrSession) || called {
			t.Fatalf("invalid session entered delivery: called=%t err=%v", called, err)
		}
	}
	if _, err := pool.Exec(ctx, `UPDATE users SET blocked_at=now() WHERE id=$1`, id); err != nil {
		t.Fatal(err)
	}
	deny()
	if _, err := pool.Exec(ctx, `UPDATE users SET blocked_at=NULL,role='ADMINISTRATOR' WHERE id=$1`, id); err != nil {
		t.Fatal(err)
	}
	deny()
	principal.Role = "ADMINISTRATOR"
	if _, err := pool.Exec(ctx, `UPDATE sessions SET expires_at=now()-interval '1 second' WHERE token_digest=$1`, token.Digest[:]); err != nil {
		t.Fatal(err)
	}
	deny()
	if _, err := pool.Exec(ctx, `UPDATE sessions SET expires_at=now()+interval '1 day' WHERE token_digest=$1`, token.Digest[:]); err != nil {
		t.Fatal(err)
	}
	if _, err := pool.Exec(ctx, `DELETE FROM support_product_identity WHERE singleton=true`); err != nil {
		t.Fatal(err)
	}
	called := false
	err = guard.WithSession(ctx, principal, func(context.Context) error { called = true; return nil })
	if !errors.Is(err, ErrUnavailable) || called {
		t.Fatalf("missing support identity allowed delivery: called=%t err=%v", called, err)
	}
}

func TestNilDatabaseIsRejected(t *testing.T) {
	if _, err := New(nil, 1, time.Second); !errors.Is(err, ErrUnavailable) {
		t.Fatalf("nil database: %v", err)
	}
}
