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

type fakeSub struct {
	events    chan coordinator.State
	current   atomic.Bool
	refreshes atomic.Int32
}

func (s *fakeSub) Events() <-chan coordinator.State { return s.events }
func (s *fakeSub) Current(coordinator.State) bool   { return s.current.Load() }
func (s *fakeSub) RequestRefresh() bool             { s.refreshes.Add(1); return true }

type checkFunc func(context.Context, string, auth.Principal, roster.Result) error

func (f checkFunc) Check(ctx context.Context, token string, principal auth.Principal, result roster.Result) error {
	return f(ctx, token, principal, result)
}

func newSub() *fakeSub {
	s := &fakeSub{events: make(chan coordinator.State, 4)}
	s.current.Store(true)
	return s
}
func result(t *testing.T, events <-chan Delivery) Delivery {
	t.Helper()
	select {
	case value, ok := <-events:
		if !ok {
			t.Fatal("delivery closed")
		}
		return value
	case <-time.After(time.Second):
		t.Fatal("delivery timed out")
		return Delivery{}
	}
}
