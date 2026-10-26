package dispatchdelivery

import (
	"context"
	"errors"
	"github.com/jackc/pgx/v5"
	"time"
	reader "voice-platform/backend/internal/notifications/read_delivery_context"
	d "voice-platform/backend/internal/notifications/register_device"
)

type admission struct {
	device d.Record
	author string
}

func check(ctx context.Context, tx pgx.Tx, job Job, scope reader.Scope, now time.Time) (admission, string, error) {
	source := reader.New(tx)
	m, err := source.Message(ctx, job.Kind, job.MessageID)
	if errors.Is(err, reader.ErrUnavailable) {
		return admission{}, "target_unavailable", nil
	}
	if err != nil {
		return admission{}, "", err
	}
	if m.ConversationID != job.ConversationID {
		return admission{}, "target_unavailable", nil
	}
	var original []string
	if err = tx.QueryRow(ctx, `SELECT mention_user_ids::text[] FROM notification_outbox WHERE id=$1::uuid`, job.OutboxID).Scan(&original); err != nil {
		return admission{}, "", err
	}
	device, err := source.Binding(ctx, job.BindingID, job.AccountID, scope.Origin, scope.InstallationID, scope.Namespace, now)
	if errors.Is(err, reader.ErrUnavailable) {
		return admission{}, "revoked", nil
	}
	if err != nil {
		return admission{}, "", err
	}
	result, err := source.Evaluate(ctx, job.AccountID, m, original, device, now, job.ExpiresAt.Sub(job.CreatedAt))
	out := admission{device, m.AuthorID}
	if err != nil {
		return out, "", err
	}
	if !result.Eligible {
		return out, result.Reason, nil
	}
	return out, "", nil
}
