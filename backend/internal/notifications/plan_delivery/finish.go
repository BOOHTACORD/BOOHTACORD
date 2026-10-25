package plandelivery

import (
	"context"
	"github.com/jackc/pgx/v5"
)

func commitCreated(ctx context.Context, tx pgx.Tx, created int) error {
	if created > 0 {
		if _, err := tx.Exec(ctx, `UPDATE notification_runtime_policy SET delivery_pending=delivery_pending+$1 WHERE singleton`, created); err != nil {
			return err
		}
	}
	return tx.Commit(ctx)
}
func finish(ctx context.Context, tx pgx.Tx, in Intent, state, reason string) error {
	changed, err := tx.Exec(ctx, `UPDATE notification_outbox SET state=$3,reason=$4,lease_owner=NULL,lease_until=NULL WHERE id=$1::uuid AND lease_owner=$2::uuid AND state='planning'`, in.ID, in.LeaseOwner, state, reason)
	if err != nil {
		return err
	}
	if changed.RowsAffected() != 1 {
		return ErrLostLease
	}
	_, err = tx.Exec(ctx, `UPDATE notification_runtime_policy SET intent_pending=intent_pending-1 WHERE singleton`)
	return err
}
