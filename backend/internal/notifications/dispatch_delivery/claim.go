package dispatchdelivery

import (
	"context"
	"errors"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"time"
	control "voice-platform/backend/internal/notifications/control_delivery"
	observe "voice-platform/backend/internal/notifications/observe_delivery"
)

type Database interface {
	BeginTx(context.Context, pgx.TxOptions) (pgx.Tx, error)
}
type Store struct{ database Database }

func New(database Database) Store { return Store{database} }

var ErrLostLease = errors.New("notification delivery claim no longer owned")

func (s Store) Claim(ctx context.Context, now time.Time) (Job, bool, error) {
	ctx, endSpan := observe.Span(ctx, "notification.claim")
	defer endSpan()
	ctx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()
	tx, err := s.database.BeginTx(ctx, pgx.TxOptions{})
	if err != nil {
		return Job{}, false, err
	}
	defer rollback(tx)
	policy, err := control.Lock(ctx, tx)
	if err != nil {
		return Job{}, false, err
	}
	if !policy.Enabled {
		return Job{}, false, nil
	}
	token := uuid.NewString()
	var job Job
	err = tx.QueryRow(ctx, `WITH candidate AS(SELECT id FROM notification_deliveries
 WHERE state IN('pending','retry','claimed') AND due_at<=$1 AND (lease_until IS NULL OR lease_until<$1) AND epoch=$2
 ORDER BY due_at,id LIMIT 1 FOR UPDATE SKIP LOCKED)
 UPDATE notification_deliveries j SET state='claimed',lease_owner=$3::uuid,lease_until=$1+interval '30 seconds'
 FROM candidate WHERE j.id=candidate.id
 RETURNING j.id::text,j.outbox_id::text,j.binding_id::text,j.account_id::text,j.kind,j.conversation_id::text,j.message_id::text,j.template,j.group_ref::text,j.binding_generation,j.epoch,j.created_at,j.expires_at,j.due_at,j.attempts,j.attempt_started_at,j.lease_owner::text`, now, policy.Epoch, token).Scan(&job.ID, &job.OutboxID, &job.BindingID, &job.AccountID, &job.Kind, &job.ConversationID, &job.MessageID, &job.Template, &job.GroupRef, &job.BindingGeneration, &job.Epoch, &job.CreatedAt, &job.ExpiresAt, &job.DueAt, &job.Attempts, &job.AttemptStartedAt, &job.LeaseOwner)
	if errors.Is(err, pgx.ErrNoRows) {
		return Job{}, false, nil
	}
	if err != nil {
		return Job{}, false, err
	}
	if err = tx.Commit(ctx); err != nil {
		return Job{}, false, err
	}
	return job, true, nil
}
func rollback(tx pgx.Tx) {
	ctx, cancel := context.WithTimeout(context.Background(), time.Second)
	defer cancel()
	_ = tx.Rollback(ctx)
}
