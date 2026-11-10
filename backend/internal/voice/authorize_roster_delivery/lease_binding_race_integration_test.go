package authorizerosterdelivery

import (
	"context"
	"errors"
	"testing"
	"time"

	"voice-platform/backend/internal/identity/session"
)

func TestLeaseSessionBindingChangeDuringLocksRejectsSnapshot(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
	defer cancel()
	f := newAtomicFixture(t, ctx)
	other, err := session.Issue()
	if err != nil {
		t.Fatal(err)
	}
	if _, err := f.pool.Exec(ctx, `INSERT INTO sessions(token_digest,user_id) VALUES($1,$2)`, other.Digest[:], f.member); err != nil {
		t.Fatal(err)
	}
	blocker, err := f.pool.Begin(ctx)
	if err != nil {
		t.Fatal(err)
	}
	defer blocker.Rollback(context.Background())
	if _, err := blocker.Exec(ctx, `SELECT id FROM users WHERE id=$1 FOR UPDATE`, f.member); err != nil {
		t.Fatal(err)
	}
	done := make(chan error, 1)
	called := false
	go func() {
		done <- f.guard.WithRoster(ctx, f.principal, f.snapshot, func(context.Context) error { called = true; return nil })
	}()
	wait, stop := context.WithTimeout(ctx, 600*time.Millisecond)
	defer stop()
	for {
		var blocked bool
		err := f.pool.QueryRow(wait, `SELECT EXISTS(SELECT 1 FROM pg_stat_activity WHERE datname=current_database() AND wait_event_type='Lock' AND query LIKE 'SELECT id FROM users WHERE id=ANY%')`).Scan(&blocked)
		if err != nil {
			t.Fatal(err)
		}
		if blocked {
			break
		}
		if wait.Err() != nil {
			t.Fatal("guard did not wait after reading lease binding")
		}
		time.Sleep(5 * time.Millisecond)
	}
	if _, err := f.pool.Exec(ctx, `UPDATE voice_leases SET session_token_digest=$2 WHERE id=$1`, f.lease, other.Digest[:]); err != nil {
		t.Fatal(err)
	}
	if err := blocker.Commit(ctx); err != nil {
		t.Fatal(err)
	}
	err = <-done
	if !errors.Is(err, ErrStale) || called {
		t.Fatalf("changed lease binding entered delivery: called=%t err=%v", called, err)
	}
}
