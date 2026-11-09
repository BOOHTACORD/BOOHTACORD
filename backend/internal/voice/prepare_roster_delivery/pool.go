// Package preparerosterdelivery reauthorizes snapshots away from socket writers.
package preparerosterdelivery

import (
	"context"
	"errors"
	"time"

	auth "voice-platform/backend/internal/identity/authenticate_session"
	coordinator "voice-platform/backend/internal/voice/coordinate_roster"
	roster "voice-platform/backend/internal/voice/list_connected_participants"
)

var ErrInvalidConfig = errors.New("invalid roster delivery preparation configuration")

type Subscription interface {
	Events() <-chan coordinator.State
	Current(coordinator.State) bool
	RequestRefresh() bool
	RetryOnNextRefresh() bool
}
type Guard interface {
	Check(context.Context, string, auth.Principal, roster.Result) error
}
type Delivery struct {
	State                       coordinator.State
	Unavailable, SessionInvalid bool
}
type Pool struct {
	slots   chan struct{}
	timeout time.Duration
}

func New(maxConcurrent int, timeout time.Duration) (*Pool, error) {
	if maxConcurrent < 1 || maxConcurrent > 16 || timeout <= 0 || timeout > 10*time.Second {
		return nil, ErrInvalidConfig
	}
	return &Pool{slots: make(chan struct{}, maxConcurrent), timeout: timeout}, nil
}

// Stream owns one bounded result slot. Terminal session invalidation replaces
// any unsent snapshot. The caller remains responsible for closing the subscription.
func (p *Pool) Stream(ctx context.Context, sub Subscription, token string, principal auth.Principal, guard Guard) (<-chan Delivery, <-chan struct{}) {
	out, done := make(chan Delivery, 1), make(chan struct{})
	go func() { defer close(done); defer close(out); p.run(ctx, sub, token, principal, guard, out) }()
	return out, done
}
