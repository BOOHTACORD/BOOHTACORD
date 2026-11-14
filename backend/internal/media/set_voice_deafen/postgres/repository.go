package setvoicedeafenpostgres

import (
	"context"
	"errors"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	identitysession "voice-platform/backend/internal/identity/session"
	"voice-platform/backend/internal/media/set_voice_deafen"
)

type Row interface{ Scan(...any) error }
type Transaction interface {
	QueryRow(context.Context, string, ...any) Row
	Commit(context.Context) error
	Rollback(context.Context) error
}
type Database interface {
	Begin(context.Context) (Transaction, error)
}
type Publisher interface {
	Publish(context.Context, string, string, bool) error
}
type Repository struct {
	database  Database
	publisher Publisher
}

const lockLease = `SELECT channel_id::text FROM voice_leases AS lease
JOIN sessions AS session ON session.token_digest=lease.session_token_digest AND session.user_id=lease.user_id
WHERE lease.id=$1::uuid AND lease.user_id=$2::uuid AND lease.session_token_digest=$3
AND lease.revoked_at IS NULL AND session.revoked_at IS NULL AND session.expires_at>clock_timestamp()
AND session.last_active_at>clock_timestamp()-($4::double precision*interval '1 second')
FOR UPDATE OF lease, session`

func New(database Database, publisher Publisher) Repository {
	return Repository{database: database, publisher: publisher}
}
func (repository Repository) Apply(ctx context.Context, principal setvoicedeafen.Principal, leaseID string, deafened bool) error {
	if uuid.Validate(principal.AccountID) != nil || uuid.Validate(leaseID) != nil {
		return setvoicedeafen.ErrInvalid
	}
	tx, err := repository.database.Begin(ctx)
	if err != nil {
		return setvoicedeafen.ErrUnavailable
	}
	defer func() { _ = tx.Rollback(ctx) }()
	var channelID string
	err = tx.QueryRow(ctx, lockLease, leaseID, principal.AccountID, principal.SessionDigest[:], int64(identitysession.IdleLifetime.Seconds())).Scan(&channelID)
	if errors.Is(err, pgx.ErrNoRows) {
		return setvoicedeafen.ErrDenied
	}
	if err != nil {
		return setvoicedeafen.ErrUnavailable
	}
	if err = repository.publisher.Publish(ctx, leaseID, channelID, deafened); err != nil {
		return setvoicedeafen.ErrUnavailable
	}
	if err = tx.Commit(ctx); err != nil {
		return setvoicedeafen.ErrUnavailable
	}
	return nil
}

type PoolDatabase struct {
	pool interface {
		Begin(context.Context) (pgx.Tx, error)
	}
}

func NewPoolDatabase(pool interface {
	Begin(context.Context) (pgx.Tx, error)
}) PoolDatabase { return PoolDatabase{pool: pool} }
func (database PoolDatabase) Begin(ctx context.Context) (Transaction, error) {
	tx, err := database.pool.Begin(ctx)
	if err != nil {
		return nil, err
	}
	return pgxTransaction{tx}, nil
}

type pgxTransaction struct{ tx pgx.Tx }

func (transaction pgxTransaction) QueryRow(ctx context.Context, query string, args ...any) Row {
	return transaction.tx.QueryRow(ctx, query, args...)
}
func (transaction pgxTransaction) Commit(ctx context.Context) error {
	return transaction.tx.Commit(ctx)
}
func (transaction pgxTransaction) Rollback(ctx context.Context) error {
	return transaction.tx.Rollback(ctx)
}
