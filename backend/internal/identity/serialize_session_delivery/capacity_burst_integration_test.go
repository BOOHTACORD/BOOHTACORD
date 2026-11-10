package serializesessiondelivery

import (
	"context"
	"errors"
	"sync"
	"testing"
	"time"

	"github.com/google/uuid"
	"voice-platform/backend/internal/database/migrate"
	auth "voice-platform/backend/internal/identity/authenticate_session"
	"voice-platform/backend/internal/identity/session"
	pgfixture "voice-platform/backend/internal/testsupport/postgres"
)

// Each blocked callback simulates a writer honoring a slow-client deadline.
// This validates guard admission only, not network backpressure or media capacity.
func TestBurstOfOneHundredWaitersIsBoundedDuringSlowWrites(t *testing.T) {
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
	if _, err := pool.Exec(ctx, `INSERT INTO users(id,login,display_name,password_hash,role) VALUES($1,'delivery_burst','Guard','x','MEMBER')`, id); err != nil {
		t.Fatal(err)
	}
	if _, err := pool.Exec(ctx, `INSERT INTO sessions(token_digest,user_id) VALUES($1,$2)`, token.Digest[:], id); err != nil {
		t.Fatal(err)
	}
	guard, err := New(pool, 4, 2*time.Second)
	if err != nil {
		t.Fatal(err)
	}
	principal := auth.Principal{AccountID: id, Role: "MEMBER", SessionDigest: token.Digest}
	entered := make(chan struct{}, 4)
	release := make(chan struct{})
	var holders sync.WaitGroup
	for i := 0; i < 4; i++ {
		holders.Add(1)
		go func() {
			defer holders.Done()
			_ = guard.WithSession(ctx, principal, func(ctx context.Context) error {
				entered <- struct{}{}
				select {
				case <-release:
					return nil
				case <-ctx.Done():
					return ctx.Err()
				}
			})
		}()
	}
	for i := 0; i < 4; i++ {
		select {
		case <-entered:
		case <-ctx.Done():
			t.Fatal("writers did not start")
		}
	}
	var waiters sync.WaitGroup
	failures := make(chan error, 100)
	for i := 0; i < 100; i++ {
		waiters.Add(1)
		go func() {
			defer waiters.Done()
			deadline, stop := context.WithTimeout(ctx, 100*time.Millisecond)
			defer stop()
			called := false
			err := guard.WithSession(deadline, principal, func(context.Context) error { called = true; return nil })
			if !errors.Is(err, ErrUnavailable) || called {
				failures <- err
			}
		}()
	}
	waiters.Wait()
	close(failures)
	for err := range failures {
		t.Errorf("waiter admitted during saturation: %v", err)
	}
	close(release)
	holders.Wait()
	if err := guard.WithSession(ctx, principal, func(context.Context) error { return nil }); err != nil {
		t.Fatalf("guard did not recover: %v", err)
	}
}
