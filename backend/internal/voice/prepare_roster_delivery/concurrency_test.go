package preparerosterdelivery

import (
	"context"
	"sync/atomic"
	"testing"
	"time"

	auth "voice-platform/backend/internal/identity/authenticate_session"
	coordinator "voice-platform/backend/internal/voice/coordinate_roster"
	roster "voice-platform/backend/internal/voice/list_connected_participants"
)

func TestConcurrentChecksAreBoundedAndCancelable(t *testing.T) {
	pool, err := New(2, time.Second)
	if err != nil {
		t.Fatal(err)
	}
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	started := make(chan struct{}, 10)
	release := make(chan struct{})
	var active, peak atomic.Int32
	checker := checkFunc(func(ctx context.Context, _ string, _ auth.Principal, _ roster.Result) error {
		count := active.Add(1)
		defer active.Add(-1)
		for old := peak.Load(); count > old && !peak.CompareAndSwap(old, count); old = peak.Load() {
		}
		started <- struct{}{}
		select {
		case <-release:
			return nil
		case <-ctx.Done():
			return ctx.Err()
		}
	})
	var done []<-chan struct{}
	for i := 0; i < 10; i++ {
		sub := newSub()
		_, stopped := pool.Stream(ctx, sub, "opaque", auth.Principal{}, checker)
		done = append(done, stopped)
		sub.events <- coordinator.State{Revision: 1}
	}
	for i := 0; i < 2; i++ {
		select {
		case <-started:
		case <-time.After(time.Second):
			t.Fatal("check did not start")
		}
	}
	select {
	case <-started:
		t.Fatal("guard concurrency exceeded")
	case <-time.After(50 * time.Millisecond):
	}
	cancel()
	for _, stopped := range done {
		select {
		case <-stopped:
		case <-time.After(time.Second):
			t.Fatal("worker did not stop")
		}
	}
	close(release)
	if peak.Load() > 2 {
		t.Fatalf("peak checks: %d", peak.Load())
	}
}

func TestSupersededResultIsNotPublished(t *testing.T) {
	pool, _ := New(1, time.Second)
	sub := newSub()
	started, release := make(chan struct{}), make(chan struct{})
	var calls atomic.Int32
	checker := checkFunc(func(ctx context.Context, _ string, _ auth.Principal, _ roster.Result) error {
		if calls.Add(1) == 1 {
			close(started)
			select {
			case <-release:
			case <-ctx.Done():
				return ctx.Err()
			}
		}
		return nil
	})
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	out, _ := pool.Stream(ctx, sub, "opaque", auth.Principal{}, checker)
	sub.events <- coordinator.State{Revision: 1}
	<-started
	sub.events <- coordinator.State{Revision: 2}
	close(release)
	if value := result(t, out); value.State.Revision != 2 {
		t.Fatalf("superseded state delivered: %+v", value)
	}
}

func TestInvalidatedObservationRequestsRefreshWithoutGuard(t *testing.T) {
	pool, _ := New(1, time.Second)
	sub := newSub()
	sub.current.Store(false)
	var calls atomic.Int32
	checker := checkFunc(func(context.Context, string, auth.Principal, roster.Result) error { calls.Add(1); return nil })
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	out, _ := pool.Stream(ctx, sub, "opaque", auth.Principal{}, checker)
	sub.events <- coordinator.State{Revision: 1}
	deadline := time.Now().Add(time.Second)
	for sub.refreshes.Load() == 0 && time.Now().Before(deadline) {
		time.Sleep(time.Millisecond)
	}
	if sub.refreshes.Load() != 1 || calls.Load() != 0 {
		t.Fatal("invalidated state was not refreshed")
	}
	select {
	case value := <-out:
		t.Fatalf("invalidated state emitted: %+v", value)
	default:
	}
}
