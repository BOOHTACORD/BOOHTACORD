package preparerosterdelivery

import (
	"context"
	"errors"
	"sync/atomic"
	"testing"
	"time"

	auth "voice-platform/backend/internal/identity/authenticate_session"
	guard "voice-platform/backend/internal/voice/authorize_roster_delivery"
	coordinator "voice-platform/backend/internal/voice/coordinate_roster"
	roster "voice-platform/backend/internal/voice/list_connected_participants"
)

func TestValidStaleAndUnavailableAreDistinct(t *testing.T) {
	pool, err := New(2, time.Second)
	if err != nil {
		t.Fatal(err)
	}
	sub := newSub()
	var mode atomic.Int32
	checker := checkFunc(func(context.Context, string, auth.Principal, roster.Result) error {
		switch mode.Load() {
		case 1:
			return guard.ErrStale
		case 2:
			return errors.New("private failure")
		}
		return nil
	})
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	out, _ := pool.Stream(ctx, sub, "opaque", auth.Principal{}, checker)
	sub.events <- coordinator.State{Revision: 1}
	if value := result(t, out); value.Unavailable || value.SessionInvalid || value.State.Revision != 1 {
		t.Fatalf("valid: %+v", value)
	}
	mode.Store(1)
	sub.events <- coordinator.State{Revision: 2}
	deadline := time.Now().Add(time.Second)
	for sub.refreshes.Load() == 0 && time.Now().Before(deadline) {
		time.Sleep(time.Millisecond)
	}
	if sub.refreshes.Load() != 1 {
		t.Fatal("stale state did not request refresh")
	}
	select {
	case value := <-out:
		t.Fatalf("stale state emitted: %+v", value)
	default:
	}
	mode.Store(2)
	sub.events <- coordinator.State{Revision: 3}
	if value := result(t, out); !value.Unavailable || value.SessionInvalid || len(value.State.Roster.Channels) != 0 {
		t.Fatalf("unavailable: %+v", value)
	}
}

func TestInvalidatedStateAndRevocationOverrideQueuedSnapshot(t *testing.T) {
	pool, _ := New(1, time.Second)
	sub := newSub()
	var mode atomic.Int32
	checker := checkFunc(func(context.Context, string, auth.Principal, roster.Result) error {
		if mode.Load() == 1 {
			return guard.ErrSession
		}
		return nil
	})
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	out, done := pool.Stream(ctx, sub, "opaque", auth.Principal{}, checker)
	sub.events <- coordinator.State{Revision: 1}
	deadline := time.Now().Add(time.Second)
	for len(out) == 0 && time.Now().Before(deadline) {
		time.Sleep(time.Millisecond)
	}
	mode.Store(1)
	sub.events <- coordinator.State{Revision: 2}
	select {
	case <-done:
	case <-time.After(time.Second):
		t.Fatal("revocation not processed")
	}
	value := result(t, out)
	if !value.SessionInvalid || value.State.Revision != 0 {
		t.Fatalf("revocation lost: %+v", value)
	}
}
