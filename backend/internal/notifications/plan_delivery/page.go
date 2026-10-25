package plandelivery

import (
	"context"
	"errors"
	"github.com/jackc/pgx/v5"
	"time"
	control "voice-platform/backend/internal/notifications/control_delivery"
	observe "voice-platform/backend/internal/notifications/observe_delivery"
	reader "voice-platform/backend/internal/notifications/read_delivery_context"
)

var ErrLostLease = errors.New("notification planning claim no longer owned")

type PlanResult struct {
	Created  int
	Complete bool
}

func (s Store) Page(ctx context.Context, in Intent, scope reader.Scope, now time.Time) (PlanResult, error) {
	ctx, endSpan := observe.Span(ctx, "notification.plan")
	defer endSpan()
	ctx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()
	tx, err := s.database.BeginTx(ctx, pgx.TxOptions{})
	if err != nil {
		return PlanResult{}, err
	}
	defer rollback(tx)
	policy, err := control.Lock(ctx, tx)
	if err != nil {
		return PlanResult{}, err
	}
	var owned bool
	err = tx.QueryRow(ctx, `SELECT EXISTS(SELECT 1 FROM notification_outbox WHERE id=$1::uuid AND lease_owner=$2::uuid AND lease_until>$3 AND state='planning')`, in.ID, in.LeaseOwner, now).Scan(&owned)
	if err != nil {
		return PlanResult{}, err
	}
	if !owned || !policy.Enabled || policy.Epoch != in.Epoch {
		return PlanResult{}, ErrLostLease
	}
	complete := func(state, reason string) (PlanResult, error) {
		if err := finish(ctx, tx, in, state, reason); err != nil {
			return PlanResult{}, err
		}
		return PlanResult{Complete: true}, tx.Commit(ctx)
	}
	if !in.ExpiresAt.After(now) {
		return complete("expired", "expired")
	}
	if in.InstallationID != scope.InstallationID {
		return complete("suppressed", "operator_disabled")
	}
	source := reader.New(tx)
	message, err := source.Message(ctx, in.Kind, in.MessageID)
	if errors.Is(err, reader.ErrUnavailable) {
		return complete("suppressed", "target_unavailable")
	}
	if err != nil {
		return PlanResult{}, err
	}
	if message.ConversationID != in.ConversationID || message.AuthorID != in.AuthorID || message.Deleted || message.Archived || message.AuthorBlocked {
		return complete("suppressed", "target_unavailable")
	}
	candidates, err := source.Candidates(ctx, message, in.Mentions, in.Cursor, scope, now)
	if err != nil {
		return PlanResult{}, err
	}
	result := PlanResult{}
	for _, account := range candidates {
		nodes, err := source.Devices(ctx, account, scope, now)
		if err != nil {
			return result, err
		}
		for _, node := range nodes {
			allowed, err := source.Evaluate(ctx, account, message, in.Mentions, node, now, in.ExpiresAt.Sub(in.CreatedAt))
			if err != nil {
				return result, err
			}
			if !allowed.Eligible {
				if err = observe.Record(ctx, tx, "suppressed", allowed.Reason, node.Transport, 1); err != nil {
					return result, err
				}
				continue
			}
			if policy.DeliveryPending+result.Created >= policy.MaxDeliveries {
				if err = observe.Record(ctx, tx, "queue_drop", "queue_full", node.Transport, 1); err != nil {
					return result, err
				}
				if err = finish(ctx, tx, in, "done", "queue_full"); err != nil {
					return result, err
				}
				result.Complete = true
				return result, commitCreated(ctx, tx, result.Created)
			}
			added, err := insertJob(ctx, tx, in, message, account, node, now)
			if err != nil {
				return result, err
			}
			result.Created += added
			if err = observe.Record(ctx, tx, "eligible", "eligible", node.Transport, int64(added)); err != nil {
				return result, err
			}
		}
	}
	if len(candidates) < reader.CandidatePageSize {
		if err = finish(ctx, tx, in, "done", "planned"); err != nil {
			return result, err
		}
		result.Complete = true
	} else {
		_, err = tx.Exec(ctx, `UPDATE notification_outbox SET cursor_account=$3::uuid,state='pending',due_at=$4,lease_owner=NULL,lease_until=NULL WHERE id=$1::uuid AND lease_owner=$2::uuid`, in.ID, in.LeaseOwner, candidates[len(candidates)-1], now)
		if err != nil {
			return result, err
		}
	}
	return result, commitCreated(ctx, tx, result.Created)
}
