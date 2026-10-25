package dispatchdelivery

import (
	"context"
	"errors"
	"github.com/jackc/pgx/v5"
)

func owned(ctx context.Context, tx pgx.Tx, claim Job) (Job, bool, error) {
	var j Job
	var presented bool
	err := tx.QueryRow(ctx, `SELECT id::text,outbox_id::text,binding_id::text,account_id::text,kind,conversation_id::text,message_id::text,template,group_ref::text,
 binding_generation,epoch,created_at,expires_at,due_at,attempts,attempt_started_at,lease_owner::text,presented_at IS NOT NULL,lease_until
 FROM notification_deliveries WHERE id=$1::uuid AND lease_owner=$2::uuid AND state='claimed' FOR UPDATE`, claim.ID, claim.LeaseOwner).Scan(
		&j.ID, &j.OutboxID, &j.BindingID, &j.AccountID, &j.Kind, &j.ConversationID, &j.MessageID, &j.Template, &j.GroupRef, &j.BindingGeneration, &j.Epoch, &j.CreatedAt, &j.ExpiresAt, &j.DueAt, &j.Attempts, &j.AttemptStartedAt, &j.LeaseOwner, &presented, &j.LeaseUntil)
	if errors.Is(err, pgx.ErrNoRows) {
		return j, false, ErrLostLease
	}
	return j, presented, err
}
