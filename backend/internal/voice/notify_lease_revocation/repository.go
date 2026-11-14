package notifyleaserevocation

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/google/uuid"
)

var ErrInvalidClaimLimit = errors.New("invalid voice lease revocation notification claim limit")
var ErrStaleClaim = errors.New("stale voice lease revocation notification claim")

const claimPending = `
WITH candidates AS (
    SELECT revocation.lease_id
    FROM voice_sfu_revocations AS revocation
    JOIN voice_leases AS lease ON lease.id = revocation.lease_id
    WHERE revocation.notification_emitted_at IS NULL
      AND (lease.revocation_reason <> 'AFK_MOVE' OR revocation.completed_at IS NOT NULL)
      AND (revocation.notification_claim_token IS NULL OR revocation.notification_claimed_at < now() - interval '30 seconds')
    ORDER BY revocation.requested_at, revocation.lease_id
    LIMIT $1
    FOR UPDATE SKIP LOCKED
), claimed AS (
    UPDATE voice_sfu_revocations AS revocation
    SET notification_claim_token = $2::uuid,
        notification_claimed_at = now()
    FROM candidates
    WHERE revocation.lease_id = candidates.lease_id
    RETURNING revocation.lease_id, revocation.requested_at, revocation.trace_cause
)
SELECT claimed.lease_id::text, lease.user_id::text, lease.revocation_reason, claimed.requested_at, claimed.trace_cause, revocation.target_channel_id::text
FROM claimed JOIN voice_leases AS lease ON lease.id = claimed.lease_id JOIN voice_sfu_revocations AS revocation ON revocation.lease_id=claimed.lease_id
ORDER BY claimed.requested_at, claimed.lease_id`

const markEmitted = `
UPDATE voice_sfu_revocations
SET notification_emitted_at = now(),
    notification_claim_token = NULL,
    notification_claimed_at = NULL
WHERE lease_id = $1::uuid AND notification_claim_token = $2::uuid
  AND notification_emitted_at IS NULL`

type Item struct {
	LeaseID, UserID, Reason, ClaimToken string
	TargetChannelID                     *string
	RequestedAt                         time.Time
	TraceCause                          []byte
}

type Rows interface {
	Next() bool
	Scan(...any) error
	Close()
	Err() error
}

type Database interface {
	Query(context.Context, string, ...any) (Rows, error)
	Exec(context.Context, string, ...any) (int64, error)
}

type Repository struct{ database Database }

func NewRepository(database Database) Repository { return Repository{database: database} }

func (repository Repository) Claim(context context.Context, limit int) ([]Item, error) {
	if limit < 1 || limit > 100 {
		return nil, ErrInvalidClaimLimit
	}
	claimToken := uuid.NewString()
	rows, err := repository.database.Query(context, claimPending, limit, claimToken)
	if err != nil {
		return nil, fmt.Errorf("claim voice lease revocation notifications: %w", err)
	}
	defer rows.Close()
	items := make([]Item, 0, limit)
	for rows.Next() {
		item := Item{ClaimToken: claimToken}
		if err := rows.Scan(&item.LeaseID, &item.UserID, &item.Reason, &item.RequestedAt, &item.TraceCause, &item.TargetChannelID); err != nil {
			return nil, fmt.Errorf("scan voice lease revocation notification: %w", err)
		}
		items = append(items, item)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterate voice lease revocation notifications: %w", err)
	}
	return items, nil
}

func (repository Repository) MarkEmitted(context context.Context, item Item) error {
	affected, err := repository.database.Exec(context, markEmitted, item.LeaseID, item.ClaimToken)
	if err != nil {
		return fmt.Errorf("mark voice lease revocation notification emitted: %w", err)
	}
	if affected != 1 {
		return ErrStaleClaim
	}
	return nil
}
