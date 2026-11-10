// Package serializesessiondelivery orders bounded writes with session revocation.
package serializesessiondelivery

import (
	"context"
	"errors"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	auth "voice-platform/backend/internal/identity/authenticate_session"
)

var ErrSession = errors.New("delivery session invalid")
var ErrUnavailable = errors.New("delivery authorization unavailable")

type Guard struct {
	database *pgxpool.Pool
	slots    chan struct{}
	timeout  time.Duration
}

func New(database *pgxpool.Pool, concurrency int, timeout time.Duration) (*Guard, error) {
	if database == nil || concurrency < 1 || concurrency > 4 || timeout <= 0 || timeout > 2*time.Second {
		return nil, ErrUnavailable
	}
	return &Guard{database: database, slots: make(chan struct{}, concurrency), timeout: timeout}, nil
}

// WithSession holds shared PostgreSQL row locks until the callback returns.
// The callback must honor its context; no event-hub lock may be held here.
func (g *Guard) WithSession(parent context.Context, principal auth.Principal, write func(context.Context) error) error {
	if write == nil {
		return ErrUnavailable
	}
	return g.WithSessionTx(parent, principal, func(ctx context.Context, _ pgx.Tx) error { return write(ctx) })
}

// WithSessionTx also exposes the locked transaction to resource-specific guards.
func (g *Guard) WithSessionTx(parent context.Context, principal auth.Principal, write func(context.Context, pgx.Tx) error) error {
	if g == nil || write == nil || principal.AccountID == "" || principal.Role == "" {
		return ErrUnavailable
	}
	ctx, cancel := context.WithTimeout(parent, g.timeout)
	defer cancel()
	select {
	case g.slots <- struct{}{}:
	case <-ctx.Done():
		return ErrUnavailable
	}
	defer func() { <-g.slots }()
	tx, err := g.database.Begin(ctx)
	if err != nil {
		return ErrUnavailable
	}
	defer rollback(tx)
	ttl, err := lockActiveSession(ctx, tx, principal)
	if err != nil {
		return err
	}
	deadline, stop := context.WithTimeout(ctx, ttl)
	defer stop()
	if err := write(deadline, tx); err != nil {
		return err
	}
	if deadline.Err() != nil {
		return ErrUnavailable
	}
	return nil
}

func rollback(tx pgx.Tx) {
	ctx, cancel := context.WithTimeout(context.Background(), time.Second)
	defer cancel()
	_ = tx.Rollback(ctx)
}
