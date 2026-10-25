package registerdevicepostgres

import (
	"context"
	"errors"
	"github.com/google/uuid"
	"sync"
	"testing"
	d "voice-platform/backend/internal/notifications/register_device"
)

func TestConcurrentRetryIsIdempotent(t *testing.T) {
	pool := newPool(t)
	store := New(pool)
	r := record()
	start := make(chan struct{})
	var wg sync.WaitGroup
	results := make(chan d.Record, 12)
	failures := make(chan error, 12)
	for i := 0; i < 12; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			<-start
			candidate := r
			candidate.ID = uuid.NewString()
			saved, err := store.Register(context.Background(), candidate, 0)
			if err != nil {
				failures <- err
			} else {
				results <- saved
			}
		}()
	}
	close(start)
	wg.Wait()
	close(results)
	close(failures)
	for err := range failures {
		t.Error(err)
	}
	id := ""
	for saved := range results {
		if id == "" {
			id = saved.ID
		}
		if saved.ID != id || saved.Generation != 1 {
			t.Fatal("retry created another binding")
		}
	}
	var rows int
	if err := pool.QueryRow(context.Background(), `SELECT count(*) FROM notification_devices`).Scan(&rows); err != nil || rows != 1 {
		t.Fatal(rows, err)
	}
}
func TestGenerationFenceAndConcurrentLogout(t *testing.T) {
	ctx := context.Background()
	pool := newPool(t)
	store := New(pool)
	r := record()
	first, err := store.Register(ctx, r, 0)
	if err != nil {
		t.Fatal(err)
	}
	next := first
	next.Generation = 2
	next.RegistrationHash = [32]byte{7}
	if _, err = store.Register(ctx, next, 1); err != nil {
		t.Fatal(err)
	}
	if _, err = store.Register(ctx, r, 0); !errors.Is(err, d.ErrConflict) {
		t.Fatal("old initial callback accepted", err)
	}
	if replay, replayErr := store.Register(ctx, next, 1); replayErr != nil || replay.Generation != 2 || replay.ID != next.ID {
		t.Fatal("identical rotation retry was not idempotent", replayErr)
	}
	changed := next
	changed.RegistrationHash = [32]byte{8}
	if _, err = store.Register(ctx, changed, 1); !errors.Is(err, d.ErrConflict) {
		t.Fatal("different old rotation accepted", err)
	}
	if _, err = pool.Exec(ctx, `UPDATE sessions SET revoked_at=now() WHERE token_digest=$1`, r.SessionDigest[:]); err != nil {
		t.Fatal(err)
	}
	fresh := record()
	if _, err = store.Register(ctx, fresh, 0); !errors.Is(err, d.ErrUnauthorized) {
		t.Fatal("logout session registered device", err)
	}
	fresh.SessionDigest = [32]byte{2}
	if _, err = store.Register(ctx, fresh, 0); err != nil {
		t.Fatal("other live session was disabled", err)
	}
}
func TestDestinationCannotBeStolenByOtherAccount(t *testing.T) {
	ctx := context.Background()
	pool := newPool(t)
	store := New(pool)
	first := record()
	if _, err := store.Register(ctx, first, 0); err != nil {
		t.Fatal(err)
	}
	attempt := record()
	attempt.AccountID = other
	attempt.SessionDigest = [32]byte{3}
	attempt.Fingerprint = first.Fingerprint
	if _, err := store.Register(ctx, attempt, 0); !errors.Is(err, d.ErrConflict) {
		t.Fatal("other account replaced endpoint", err)
	}
}
