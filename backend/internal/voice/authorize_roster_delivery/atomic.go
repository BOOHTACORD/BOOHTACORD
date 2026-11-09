package authorizerosterdelivery

import (
	"context"
	"errors"

	"github.com/jackc/pgx/v5"
	auth "voice-platform/backend/internal/identity/authenticate_session"
	sessiondelivery "voice-platform/backend/internal/identity/serialize_session_delivery"
	roster "voice-platform/backend/internal/voice/list_connected_participants"
	rosterpostgres "voice-platform/backend/internal/voice/list_connected_participants/postgres"
)

type transactionDelivery interface {
	WithSessionTx(context.Context, auth.Principal, func(context.Context, pgx.Tx) error) error
}

// WithRoster repeats authorization while resource rows remain locked through write.
func (g Guard) WithRoster(ctx context.Context, principal auth.Principal, snapshot roster.Result, write func(context.Context) error) error {
	if g.delivery == nil || write == nil {
		return ErrUnavailable
	}
	ids, err := snapshotIDs(snapshot)
	if err != nil {
		return ErrStale
	}
	err = g.delivery.WithSessionTx(ctx, principal, func(ctx context.Context, tx pgx.Tx) error {
		deadline, err := lockSnapshotRows(ctx, tx, ids)
		if errors.Is(err, ErrStale) {
			return ErrStale
		}
		if err != nil {
			return ErrUnavailable
		}
		visible, err := rosterpostgres.New(transactionDatabase{tx}).ListVisible(ctx, principal.AccountID)
		if err != nil || ctx.Err() != nil {
			return ErrUnavailable
		}
		if !matches(snapshot, visible) {
			return ErrStale
		}
		if deadline.IsZero() {
			return write(ctx)
		}
		bounded, cancel := context.WithDeadline(ctx, deadline)
		defer cancel()
		if bounded.Err() != nil {
			return ErrStale
		}
		return write(bounded)
	})
	if errors.Is(err, sessiondelivery.ErrSession) {
		return ErrSession
	}
	if errors.Is(err, sessiondelivery.ErrUnavailable) {
		return ErrUnavailable
	}
	return err
}

type transactionDatabase struct{ tx pgx.Tx }

func (db transactionDatabase) Query(ctx context.Context, sql string, args ...any) (rosterpostgres.Rows, error) {
	return db.tx.Query(ctx, sql, args...)
}
