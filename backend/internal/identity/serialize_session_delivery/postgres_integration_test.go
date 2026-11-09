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

func TestPostgresOrdersSessionRevocationAndDelivery(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
	defer cancel()
	pool := pgfixture.New(t, ctx, "VOICE_PLATFORM_TEST_DATABASE_URL", pgfixture.LoopbackIP)
	if err := migrate.Run(ctx, pool); err != nil {
		t.Fatal(err)
	}
	account := uuid.NewString()
	token, err := session.Issue()
	if err != nil {
		t.Fatal(err)
	}
	if _, err := pool.Exec(ctx, `INSERT INTO users(id,login,display_name,password_hash,role) VALUES($1,'delivery_guard','Guard','x','MEMBER')`, account); err != nil {
		t.Fatal(err)
	}
	if _, err := pool.Exec(ctx, `INSERT INTO sessions(token_digest,user_id) VALUES($1,$2)`, token.Digest[:], account); err != nil {
		t.Fatal(err)
	}
	guard, err := New(pool, 2, time.Second)
	if err != nil {
		t.Fatal(err)
	}
	principal := auth.Principal{AccountID: account, Role: "MEMBER", SessionDigest: token.Digest}
	entered, release := make(chan struct{}), make(chan struct{})
	delivery := make(chan error, 1)
	go func() {
		delivery <- guard.WithSession(ctx, principal, func(ctx context.Context) error {
			close(entered)
			select {
			case <-release:
				return nil
			case <-ctx.Done():
				return ctx.Err()
			}
		})
	}()
	select {
	case <-entered:
	case <-ctx.Done():
		t.Fatal("guard did not begin delivery")
	}
	conn, err := pool.Acquire(ctx)
	if err != nil {
		t.Fatal(err)
	}
	defer conn.Release()
	var pid int32
	if err := conn.QueryRow(ctx, `SELECT pg_backend_pid()`).Scan(&pid); err != nil {
		t.Fatal(err)
	}
	revoked, started, finished := make(chan error, 1), make(chan struct{}), make(chan struct{})
	go func() {
		defer close(finished)
		close(started)
		_, err := conn.Exec(ctx, `UPDATE sessions SET revoked_at=now() WHERE token_digest=$1`, token.Digest[:])
		revoked <- err
	}()
	defer func() { cancel(); <-finished }()
	<-started
	waitForDatabaseLock(t, pool, pid)
	select {
	case err := <-revoked:
		t.Fatalf("revoke finished during delivery: %v", err)
	default:
	}
	close(release)
	if err := <-delivery; err != nil {
		t.Fatal(err)
	}
	if err := <-revoked; err != nil {
		t.Fatal(err)
	}
	called := false
	err = guard.WithSession(ctx, principal, func(context.Context) error { called = true; return nil })
	if !errors.Is(err, ErrSession) || called {
		t.Fatalf("revoked session entered delivery: called=%t err=%v", called, err)
	}
}
