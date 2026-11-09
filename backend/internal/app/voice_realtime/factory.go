// Package voicerealtime binds one prepared roster stream to each socket.
package voicerealtime

import (
	"context"
	"errors"
	"net/http"
	"sync"

	auth "voice-platform/backend/internal/identity/authenticate_session"
	connectsession "voice-platform/backend/internal/realtime/connect_session"
	coordinator "voice-platform/backend/internal/voice/coordinate_roster"
	prepared "voice-platform/backend/internal/voice/prepare_roster_delivery"
)

var errUnavailable = errors.New("roster unavailable")

type Factory struct {
	coordinator *coordinator.Coordinator
	pool        *prepared.Pool
	guard       prepared.Guard
}

func New(c *coordinator.Coordinator, pool *prepared.Pool, guard prepared.Guard) *Factory {
	return &Factory{coordinator: c, pool: pool, guard: guard}
}

func (f *Factory) Open(parent context.Context, principal auth.Principal, cookie *http.Cookie) (connectsession.RosterStream, error) {
	if f == nil || f.coordinator == nil || f.pool == nil || f.guard == nil || cookie == nil || cookie.Value == "" || parent.Err() != nil {
		return nil, errUnavailable
	}
	sub, err := f.coordinator.Subscribe(principal.AccountID)
	if err != nil {
		return nil, errUnavailable
	}
	ctx, cancel := context.WithCancel(parent)
	events, _ := f.pool.Stream(ctx, sub, cookie.Value, principal, f.guard)
	return &stream{sub: sub, events: events, cancel: cancel, pool: f.pool, guard: f.guard, token: cookie.Value, principal: principal}, nil
}

type stream struct {
	sub       *coordinator.Subscription
	events    <-chan prepared.Delivery
	cancel    context.CancelFunc
	once      sync.Once
	pool      *prepared.Pool
	guard     prepared.Guard
	token     string
	principal auth.Principal
}

func (s *stream) Events() <-chan prepared.Delivery     { return s.events }
func (s *stream) Current(state coordinator.State) bool { return s.sub.Current(state) }
func (s *stream) RequestRefresh() bool                 { return s.sub.RequestRefresh() }
func (s *stream) Check(ctx context.Context, state coordinator.State) error {
	return s.pool.Check(ctx, s.guard, s.token, s.principal, state)
}
func (s *stream) Close() { s.once.Do(func() { s.cancel(); s.sub.Close() }) }
