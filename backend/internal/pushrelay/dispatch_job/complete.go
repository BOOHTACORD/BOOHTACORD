package dispatchjob

import (
	"context"
	"errors"
	"github.com/jackc/pgx/v5"
	"time"
	delivery "voice-platform/backend/internal/notifications/dispatch_delivery"
	auth "voice-platform/backend/internal/pushrelay/authorize_request"
)

func (s Store) Complete(ctx context.Context, j Job, result delivery.Result, now time.Time) error {
	ctx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()
	tx, err := s.Database.BeginTx(ctx, pgx.TxOptions{})
	if err != nil {
		return err
	}
	defer rollback(tx)
	policy, err := auth.Lock(ctx, tx)
	if err != nil {
		return err
	}
	if !policy.Enabled || policy.Epoch != j.Epoch {
		return ErrLostLease
	}
	var current int
	err = tx.QueryRow(ctx, `SELECT attempts FROM relay_jobs WHERE id=$1::uuid AND lease_owner=$2::uuid AND state='claimed' AND started_at IS NOT NULL FOR UPDATE`, j.ID, j.LeaseOwner).Scan(&current)
	if errors.Is(err, pgx.ErrNoRows) {
		return ErrLostLease
	}
	if err != nil {
		return err
	}
	state := result.Outcome
	switch state {
	case "accepted_by_provider", "delivery_unknown", "permanent_failure":
	case "invalid_binding":
		if _, err = tx.Exec(ctx, `UPDATE relay_devices SET state='invalid',generation=generation+1,updated_at=$2 WHERE id=$1::uuid AND state IN('pending','active')`, j.DeviceID, now); err != nil {
			return err
		}
	case "retry":
		wait := time.Duration(1<<min(current, 6))*time.Second + time.Duration(j.ID[0]%7)*100*time.Millisecond
		if result.RetryAfter > wait {
			wait = result.RetryAfter
		}
		if current >= 6 || !j.ExpiresAt.After(now.Add(wait)) {
			state = "expired"
		} else {
			_, err = tx.Exec(ctx, `UPDATE relay_jobs SET state='retry',started_at=NULL,lease_owner=NULL,lease_until=NULL,due_at=$3 WHERE id=$1::uuid AND lease_owner=$2::uuid`, j.ID, j.LeaseOwner, now.Add(wait))
			if err != nil {
				return err
			}
			_, err = tx.Exec(ctx, `INSERT INTO relay_counters(outcome,namespace,value)VALUES('retry',$1,1)ON CONFLICT(outcome,namespace)DO UPDATE SET value=relay_counters.value+1`, s.Namespace)
			if err != nil {
				return err
			}
			return tx.Commit(ctx)
		}
	default:
		state = "delivery_unknown"
	}
	// invalid_binding is a terminal outcome; no other tenant's route is touched.
	if state == "invalid_binding" {
		changed, err := tx.Exec(ctx, `UPDATE relay_jobs SET state='permanent_failure',lease_owner=NULL,lease_until=NULL WHERE id=$1::uuid AND lease_owner=$2::uuid`, j.ID, j.LeaseOwner)
		if err != nil {
			return err
		}
		if changed.RowsAffected() != 1 {
			return ErrLostLease
		}
		if _, err = tx.Exec(ctx, `UPDATE relay_policy SET pending=pending-1 WHERE singleton`); err != nil {
			return err
		}
		_, err = tx.Exec(ctx, `INSERT INTO relay_counters(outcome,namespace,value)VALUES('invalid_binding',$1,1)ON CONFLICT(outcome,namespace)DO UPDATE SET value=relay_counters.value+1`, s.Namespace)
		if err != nil {
			return err
		}
	} else if err = terminal(ctx, tx, j, state, s.Namespace); err != nil {
		return err
	}
	return tx.Commit(ctx)
}
