// Package voicerealtime binds one prepared roster stream to each socket.
package voicerealtime

import (
	"context"
	"errors"
	"net/http"
	"sync"
	"sync/atomic"
	"time"

	auth "voice-platform/backend/internal/identity/authenticate_session"
	connectsession "voice-platform/backend/internal/realtime/connect_session"
	guard "voice-platform/backend/internal/voice/authorize_roster_delivery"
	coordinator "voice-platform/backend/internal/voice/coordinate_roster"
	roster "voice-platform/backend/internal/voice/list_connected_participants"
	prepared "voice-platform/backend/internal/voice/prepare_roster_delivery"
)

var errUnavailable = errors.New("roster unavailable")

type Factory struct {
	coordinator *coordinator.Coordinator
	pool        *prepared.Pool
	guard       prepared.Guard
	observer    Observer
}

func New(c *coordinator.Coordinator, pool *prepared.Pool, guard prepared.Guard, observers ...Observer) *Factory {
	var observer Observer
	if len(observers) > 0 {
		observer = observers[0]
	}
	return &Factory{coordinator: c, pool: pool, guard: guard, observer: observer}
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
	if f.observer != nil {
		f.observer.RosterWSOpened()
	}
	return &stream{sub: sub, events: events, cancel: cancel, pool: f.pool, guard: f.guard, token: cookie.Value, principal: principal, observer: f.observer}, nil
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
	observer  Observer
	firstSent atomic.Bool
}

func (s *stream) Events() <-chan prepared.Delivery     { return s.events }
func (s *stream) Current(state coordinator.State) bool { return s.sub.Current(state) }
func (s *stream) RequestRefresh() bool                 { return s.sub.RequestRefresh() }
func (s *stream) Check(ctx context.Context, state coordinator.State) error {
	err := s.pool.Check(ctx, s.guard, s.token, s.principal, state)
	if ctx.Err() == nil && err != nil && !errors.Is(err, guard.ErrSession) && !errors.Is(err, guard.ErrStale) {
		s.sub.RetryOnNextRefresh()
	}
	return err
}
func (s *stream) WithRoster(ctx context.Context, state coordinator.State, write func(context.Context) error) error {
	delivery, ok := s.guard.(interface {
		WithRoster(context.Context, auth.Principal, roster.Result, func(context.Context) error) error
	})
	if !ok {
		s.sub.RetryOnNextRefresh()
		return guard.ErrUnavailable
	}
	started := time.Now()
	err := delivery.WithRoster(ctx, s.principal, state.Roster, func(ctx context.Context) error {
		err := write(ctx)
		outcome := "success"
		if err != nil {
			outcome = "failure"
		}
		s.observeFrame(time.Since(started), outcome)
		return err
	})
	if errors.Is(err, guard.ErrUnavailable) {
		s.sub.RetryOnNextRefresh()
	}
	return err
}
func (s *stream) Close() {
	s.once.Do(func() {
		s.cancel()
		s.sub.Close()
		if s.observer != nil {
			s.observer.RosterWSClosed()
		}
	})
}
