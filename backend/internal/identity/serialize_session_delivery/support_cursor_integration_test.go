package serializesessiondelivery

import (
	"context"
	"testing"
	"time"

	"github.com/google/uuid"
	"voice-platform/backend/internal/database/migrate"
	auth "voice-platform/backend/internal/identity/authenticate_session"
	"voice-platform/backend/internal/identity/session"
	pgfixture "voice-platform/backend/internal/testsupport/postgres"
)

func TestSupportCursorCanAdvanceDuringDelivery(t *testing.T) {
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
	if _, err := pool.Exec(ctx, `INSERT INTO users(id,login,display_name,password_hash,role) VALUES($1,'delivery_cursor','Guard','x','MEMBER')`, id); err != nil {
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
		t.Fatal("delivery did not begin")
	}
	updateCtx, stop := context.WithTimeout(ctx, 300*time.Millisecond)
	defer stop()
	if _, err := pool.Exec(updateCtx, `UPDATE support_product_identity SET reply_cursor=reply_cursor+1 WHERE singleton=true`); err != nil {
		t.Fatalf("ordinary support cursor update was blocked: %v", err)
	}
	close(release)
	if err := <-delivery; err != nil {
		t.Fatal(err)
	}
}
