package controlqueue

import (
	"context"
	"github.com/jackc/pgx/v5"
	"time"
	auth "voice-platform/backend/internal/pushrelay/authorize_request"
)

// Startup policy changes discard pending work for disabled physical platforms.
func (s Store) Platforms(ctx context.Context, android, ios bool) error {
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
	changed, err := tx.Exec(ctx, `UPDATE relay_jobs j SET state='revoked',lease_owner=NULL,lease_until=NULL FROM relay_devices d
 WHERE j.device_id=d.id AND j.state IN('pending','claimed','retry') AND((d.platform='android' AND NOT $1::bool)OR(d.platform='ios' AND NOT $2::bool))`, android, ios)
	if err != nil {
		return err
	}
	if _, err = tx.Exec(ctx, `UPDATE relay_policy SET pending=pending-$1 WHERE singleton`, changed.RowsAffected()); err != nil {
		return err
	}
	return tx.Commit(ctx)
}
