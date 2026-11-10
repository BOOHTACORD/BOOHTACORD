package authorizerosterdelivery

import (
	"context"
	"errors"
	"testing"
	"time"

	roster "voice-platform/backend/internal/voice/list_connected_participants"
)

func TestPostgresOrdersRosterChangesAndDelivery(t *testing.T) {
	for _, kind := range []string{"lease", "participant_session", "participant_expiry", "participant_idle", "participant_ban", "participant_rename", "channel_archive"} {
		t.Run(kind, func(t *testing.T) {
			ctx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
			defer cancel()
			f := newAtomicFixture(t, ctx)
			query, arg := `UPDATE voice_leases SET revoked_at=now(),revocation_reason='KICK' WHERE id=$1`, any(f.lease)
			switch kind {
			case "participant_session":
				query, arg = `UPDATE sessions SET revoked_at=now() WHERE token_digest=$1`, f.memberDigest
			case "participant_expiry":
				query, arg = `UPDATE sessions SET expires_at=now()-interval '1 second' WHERE token_digest=$1`, f.memberDigest
			case "participant_idle":
				query, arg = `UPDATE sessions SET last_active_at=now()-interval '31 days' WHERE token_digest=$1`, f.memberDigest
			case "participant_ban":
				query, arg = `UPDATE users SET blocked_at=now() WHERE id=$1`, f.member
			case "participant_rename":
				query, arg = `UPDATE users SET display_name='renamed' WHERE id=$1`, f.member
			case "channel_archive":
				query, arg = `UPDATE channels SET archived_at=now() WHERE id=$1`, f.room
			}
			entered, release := make(chan struct{}), make(chan struct{})
			done := make(chan error, 1)
			go func() {
				done <- f.guard.WithRoster(ctx, f.principal, f.snapshot, func(ctx context.Context) error {
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
			conn, err := f.pool.Acquire(ctx)
			if err != nil {
				t.Fatal(err)
			}
			defer conn.Release()
			var pid int32
			if err := conn.QueryRow(ctx, `SELECT pg_backend_pid()`).Scan(&pid); err != nil {
				t.Fatal(err)
			}
			changed, started, finished := make(chan error, 1), make(chan struct{}), make(chan struct{})
			go func() { defer close(finished); close(started); _, err := conn.Exec(ctx, query, arg); changed <- err }()
			defer func() { cancel(); <-finished }()
			<-started
			waitForDatabaseLock(t, f.pool, pid)
			select {
			case err := <-changed:
				t.Fatalf("change committed before delivery finished: %v", err)
			default:
			}
			close(release)
			if err := <-done; err != nil {
				t.Fatal(err)
			}
			if err := <-changed; err != nil {
				t.Fatal(err)
			}
			called := false
			err = f.guard.WithRoster(ctx, f.principal, f.snapshot, func(context.Context) error { called = true; return nil })
			if !errors.Is(err, ErrStale) || called {
				t.Fatalf("changed roster entered delivery: called=%t err=%v", called, err)
			}
		})
	}
}

func TestPostgresGuardAllowsEmptyLiveKitRoster(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
	defer cancel()
	f := newAtomicFixture(t, ctx)
	f.snapshot.Channels[0].Participants = []roster.Participant{}
	called := false
	err := f.guard.WithRoster(ctx, f.principal, f.snapshot, func(context.Context) error { called = true; return nil })
	if err != nil || !called {
		t.Fatalf("empty connected roster rejected: called=%t err=%v", called, err)
	}
}

func TestParticipantSessionExpiryBoundsDeliveryDeadline(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
	defer cancel()
	f := newAtomicFixture(t, ctx)
	if _, err := f.pool.Exec(ctx, `UPDATE sessions SET expires_at=clock_timestamp()+interval '400 milliseconds' WHERE token_digest=$1`, f.memberDigest); err != nil {
		t.Fatal(err)
	}
	err := f.guard.WithRoster(ctx, f.principal, f.snapshot, func(ctx context.Context) error {
		deadline, ok := ctx.Deadline()
		if !ok || time.Until(deadline) > 700*time.Millisecond {
			t.Fatal("participant session expiry did not bound write context")
		}
		return nil
	})
	if err != nil {
		t.Fatal(err)
	}
}
