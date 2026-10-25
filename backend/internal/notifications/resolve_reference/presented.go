package resolvereference

import (
	"context"
	"github.com/jackc/pgx/v5"
	"time"
	"voice-platform/backend/internal/identity/session"
)

// Presentation is device-local suppression, never a read cursor or receipt.
func (s Store) Presented(ctx context.Context, actor string, digest [32]byte, in Request, now time.Time) error {
	if !Valid(in) {
		return ErrNotFound
	}
	ctx, cancel := context.WithTimeout(ctx, 3*time.Second)
	defer cancel()
	tx, err := s.database.BeginTx(ctx, pgx.TxOptions{})
	if err != nil {
		return err
	}
	defer rollback(tx)
	changed, err := tx.Exec(ctx, `UPDATE notification_deliveries j SET presented_at=COALESCE(presented_at,$5)
 FROM notification_devices d JOIN sessions s ON s.token_digest=d.session_digest JOIN users u ON u.id=d.account_id
 WHERE j.id=$1::uuid AND j.account_id=$2::uuid AND j.binding_generation=$3 AND d.id=j.binding_id AND d.account_id=j.account_id
 AND d.session_digest=$4 AND d.generation=$3 AND d.state='active' AND d.expires_at>$5 AND j.expires_at>$5
 AND d.origin=$6 AND d.installation_id=$7::uuid AND d.namespace=$8 AND s.user_id=d.account_id
 AND s.revoked_at IS NULL AND s.expires_at>$5 AND s.last_active_at>$5-($9::double precision*interval '1 second') AND u.blocked_at IS NULL`, in.Ref, actor, in.Generation, digest[:], now, s.scope.Origin, s.scope.InstallationID, s.scope.Namespace, int64(session.IdleLifetime.Seconds()))
	if err != nil {
		return err
	}
	if changed.RowsAffected() != 1 {
		return ErrNotFound
	}
	return tx.Commit(ctx)
}
