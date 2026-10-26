package controlqueue

import (
	"context"
	"github.com/jackc/pgx/v5"
	"time"
	auth "voice-platform/backend/internal/pushrelay/authorize_request"
)

func (s Store) Cleanup(ctx context.Context, now time.Time) error {
	ctx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()
	tx, err := s.Database.BeginTx(ctx, pgx.TxOptions{})
	if err != nil {
		return err
	}
	defer rollback(tx)
	if _, err = auth.Lock(ctx, tx); err != nil {
		return err
	}
	changed, err := tx.Exec(ctx, `UPDATE relay_jobs SET state=CASE WHEN started_at IS NOT NULL THEN 'delivery_unknown' ELSE 'expired' END,lease_owner=NULL,lease_until=NULL
 WHERE id IN(SELECT id FROM relay_jobs WHERE state IN('pending','claimed','retry') AND expires_at<$1 AND(lease_until IS NULL OR lease_until<$1) ORDER BY expires_at LIMIT 100)`, now)
	if err != nil {
		return err
	}
	if _, err = tx.Exec(ctx, `UPDATE relay_policy SET pending=pending-$1 WHERE singleton`, changed.RowsAffected()); err != nil {
		return err
	}
	for _, query := range []string{
		`DELETE FROM relay_jobs WHERE id IN(SELECT id FROM relay_jobs WHERE state NOT IN('pending','claimed','retry') AND expires_at<$1::timestamptz-interval '1 day' ORDER BY expires_at LIMIT 100)`,
		`UPDATE relay_grants SET state='revoked' WHERE id IN(SELECT id FROM relay_grants WHERE state='active' AND expires_at<$1 LIMIT 100)`,
		`DELETE FROM relay_grants WHERE id IN(SELECT id FROM relay_grants WHERE state<>'active' AND expires_at<$1::timestamptz-interval '1 day' AND NOT EXISTS(SELECT 1 FROM relay_jobs j WHERE j.grant_id=relay_grants.id) LIMIT 100)`,
		`UPDATE relay_devices SET state='revoked' WHERE id IN(SELECT id FROM relay_devices WHERE state IN('pending','active')AND(expires_at<$1 OR state='pending'AND challenge_until<$1) LIMIT 100)`,
		`DELETE FROM relay_devices WHERE id IN(SELECT id FROM relay_devices WHERE state IN('revoked','invalid') AND updated_at<$1::timestamptz-interval '1 day' AND NOT EXISTS(SELECT 1 FROM relay_grants g WHERE g.device_id=relay_devices.id) AND NOT EXISTS(SELECT 1 FROM relay_jobs j WHERE j.device_id=relay_devices.id) LIMIT 100)`,
		`DELETE FROM relay_replays WHERE(role,subject,nonce)IN(SELECT role,subject,nonce FROM relay_replays WHERE expires_at<$1 LIMIT 100)`,
		`DELETE FROM relay_budgets WHERE(scope,subject)IN(SELECT scope,subject FROM relay_budgets WHERE window_start<$1::timestamptz-interval '1 hour' LIMIT 100)`,
	} {
		if _, err = tx.Exec(ctx, query, now); err != nil {
			return err
		}
	}
	return tx.Commit(ctx)
}
