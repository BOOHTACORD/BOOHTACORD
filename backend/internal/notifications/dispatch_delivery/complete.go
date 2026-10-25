package dispatchdelivery

import (
	"context"
	"github.com/jackc/pgx/v5"
	"time"
	control "voice-platform/backend/internal/notifications/control_delivery"
	observe "voice-platform/backend/internal/notifications/observe_delivery"
)

func (s Store) Complete(ctx context.Context, claim Job, result Result, now time.Time) error {
	ctx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()
	tx, err := s.database.BeginTx(ctx, pgx.TxOptions{})
	if err != nil {
		return err
	}
	defer rollback(tx)
	policy, err := control.Lock(ctx, tx)
	if err != nil {
		return err
	}
	j, _, err := owned(ctx, tx, claim)
	if err != nil {
		return err
	}
	if !policy.Enabled || policy.Epoch != j.Epoch || j.AttemptStartedAt == nil {
		return ErrLostLease
	}
	var transport string
	if err = tx.QueryRow(ctx, `SELECT transport FROM notification_devices WHERE id=$1::uuid`, j.BindingID).Scan(&transport); err != nil {
		return err
	}
	state, reason := result.Outcome, observe.Reason(result.Reason)
	switch state {
	case "accepted_by_relay", "accepted_by_provider", "delivery_unknown", "permanent_failure":
	case "invalid_binding":
		state = "permanent_failure"
		reason = "invalid_binding"
		if _, err = tx.Exec(ctx, `UPDATE notification_devices SET state='invalid',generation=LEAST(generation+1,1000000000),updated_at=$3 WHERE id=$1::uuid AND generation=$2 AND state='active'`, j.BindingID, j.BindingGeneration, now); err != nil {
			return err
		}
	case "retry":
		wait := time.Duration(1<<min(j.Attempts, 6))*time.Second + time.Duration(j.ID[0]%7)*100*time.Millisecond
		if result.RetryAfter > wait {
			wait = result.RetryAfter
		}
		if wait < time.Second {
			wait = time.Second
		}
		if j.Attempts >= 6 || !j.ExpiresAt.After(now.Add(wait)) {
			state = "expired"
			reason = "expired"
		} else {
			if _, err = tx.Exec(ctx, `UPDATE notification_deliveries SET state='retry',reason=$3,due_at=$4,attempt_started_at=NULL,lease_owner=NULL,lease_until=NULL WHERE id=$1::uuid AND lease_owner=$2::uuid`, j.ID, j.LeaseOwner, reason, now.Add(wait)); err != nil {
				return err
			}
			if err = releaseGroup(ctx, tx, j, false, now); err != nil {
				return err
			}
			if err = observe.Record(ctx, tx, "retry", reason, transport, 1); err != nil {
				return err
			}
			return tx.Commit(ctx)
		}
	default:
		state = "delivery_unknown"
		reason = "transport_unknown"
	}
	if err = settle(ctx, tx, j, state, reason, transport, now); err != nil {
		return err
	}
	return tx.Commit(ctx)
}

func settle(ctx context.Context, tx pgx.Tx, j Job, state, reason, transport string, now time.Time) error {
	// Persist only fixed reasons; external errors may contain tokens or URLs.
	reason = observe.Reason(reason)
	_, err := tx.Exec(ctx, `UPDATE notification_deliveries SET state=$3,reason=$4,lease_owner=NULL,lease_until=NULL,
 accepted_at=CASE WHEN $3 IN('accepted_by_provider','accepted_by_relay')THEN $5::timestamptz ELSE NULL END WHERE id=$1::uuid AND lease_owner=$2::uuid`, j.ID, j.LeaseOwner, state, reason, now)
	if err != nil {
		return err
	}
	if _, err = tx.Exec(ctx, `UPDATE notification_runtime_policy SET delivery_pending=delivery_pending-1 WHERE singleton`); err != nil {
		return err
	}
	signaled := state == "accepted_by_provider" || state == "accepted_by_relay" || state == "delivery_unknown"
	if err = releaseGroup(ctx, tx, j, signaled, now); err != nil {
		return err
	}
	metric := map[string]string{"accepted_by_provider": "provider_accepted", "accepted_by_relay": "relay_accepted", "delivery_unknown": "ambiguous", "permanent_failure": "permanent_failure", "expired": "expired", "suppressed": "suppressed"}[state]
	if reason == "invalid_binding" {
		metric = "invalid_binding"
	}
	return observe.Record(ctx, tx, metric, reason, transport, 1)
}
func releaseGroup(ctx context.Context, tx pgx.Tx, j Job, signaled bool, now time.Time) error {
	_, err := tx.Exec(ctx, `UPDATE notification_groups SET reservation_job=NULL,reservation_until=NULL,
 last_signaled_at=CASE WHEN $5 THEN $6 ELSE last_signaled_at END,updated_at=$6
 WHERE binding_id=$1::uuid AND kind=$2 AND conversation_id=$3::uuid AND(reservation_job=$4::uuid OR($5 AND reservation_job IS NULL))`, j.BindingID, j.Kind, j.ConversationID, j.ID, signaled, now)
	return err
}
