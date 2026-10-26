package cleanupdelivery

import (
	"context"
	"github.com/jackc/pgx/v5"
	"time"
	control "voice-platform/backend/internal/notifications/control_delivery"
)

type Database interface {
	BeginTx(context.Context, pgx.TxOptions) (pgx.Tx, error)
}
type Store struct{ database Database }

func New(database Database) Store { return Store{database} }

// Every maintenance pass touches at most 100 rows per table, never a full sweep.
func (s Store) Run(ctx context.Context, now time.Time) error {
	ctx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()
	tx, err := s.database.BeginTx(ctx, pgx.TxOptions{})
	if err != nil {
		return err
	}
	defer func() {
		clean, cancel := context.WithTimeout(context.Background(), time.Second)
		defer cancel()
		_ = tx.Rollback(clean)
	}()
	if _, err = control.Lock(ctx, tx); err != nil {
		return err
	}
	for _, table := range []string{"notification_outbox", "notification_deliveries"} {
		counter := "intent_pending"
		states := "'pending','planning'"
		if table == "notification_deliveries" {
			counter = "delivery_pending"
			states = "'pending','claimed','retry'"
		}
		// Names are compile-time constants, never client values. An in-flight request
		// is allowed to finish within its finite lease before TTL cleanup takes over.
		changed, err := tx.Exec(ctx, `UPDATE `+table+` SET state='expired',reason='expired',lease_owner=NULL,lease_until=NULL WHERE id IN(SELECT id FROM `+table+` WHERE expires_at<=$1 AND state IN(`+states+`) AND(lease_until IS NULL OR lease_until<$1) ORDER BY expires_at LIMIT 100)`, now)
		if err != nil {
			return err
		}
		if _, err = tx.Exec(ctx, `UPDATE notification_runtime_policy SET `+counter+`=`+counter+`-$1 WHERE singleton`, changed.RowsAffected()); err != nil {
			return err
		}
	}
	for _, query := range []string{
		`UPDATE notification_devices SET state='stale',generation=LEAST(generation+1,1000000000),secret_cipher=NULL,nonce_digest=NULL,updated_at=$1 WHERE id IN(SELECT id FROM notification_devices WHERE state='registering' AND enrollment_until<=$1 ORDER BY enrollment_until LIMIT 100)`,
		`DELETE FROM notification_deliveries WHERE id IN(SELECT id FROM notification_deliveries WHERE expires_at<$1::timestamptz-interval '1 day' AND state NOT IN('pending','claimed','retry') ORDER BY expires_at LIMIT 100)`,
		`DELETE FROM notification_outbox WHERE id IN(SELECT id FROM notification_outbox WHERE expires_at<$1::timestamptz-interval '1 day' AND state NOT IN('pending','planning') AND NOT EXISTS(SELECT 1 FROM notification_deliveries d WHERE d.outbox_id=notification_outbox.id) ORDER BY expires_at LIMIT 100)`,
		`DELETE FROM notification_groups WHERE (binding_id,kind,conversation_id)IN(SELECT binding_id,kind,conversation_id FROM notification_groups WHERE ref_until<$1::timestamptz-interval '1 day' AND NOT EXISTS(SELECT 1 FROM notification_deliveries d WHERE d.binding_id=notification_groups.binding_id AND d.kind=notification_groups.kind AND d.conversation_id=notification_groups.conversation_id) LIMIT 100)`,
		`DELETE FROM notification_attention WHERE (account_id,session_digest,view_id)IN(SELECT account_id,session_digest,view_id FROM notification_attention WHERE expires_at<$1 LIMIT 100)`,
		`DELETE FROM notification_dispatch_budgets WHERE (scope,subject)IN(SELECT scope,subject FROM notification_dispatch_budgets WHERE window_start<$1::timestamptz-interval '1 hour' LIMIT 100)`,
		`DELETE FROM notification_sender_budgets WHERE account_id IN(SELECT account_id FROM notification_sender_budgets WHERE window_start<$1::timestamptz-interval '1 hour' LIMIT 100)`,
		// Retain all live-session profile tombstones: late POST cannot resurrect them.
		`DELETE FROM notification_devices WHERE id IN(SELECT d.id FROM notification_devices d JOIN sessions s ON s.token_digest=d.session_digest WHERE(d.expires_at<$1::timestamptz-interval '1 day' OR d.state IN('revoked','invalid')) AND(s.revoked_at IS NOT NULL OR s.expires_at<$1::timestamptz-interval '1 day') AND NOT EXISTS(SELECT 1 FROM notification_deliveries j WHERE j.binding_id=d.id) LIMIT 100)`,
	} {
		if _, err = tx.Exec(ctx, query, now); err != nil {
			return err
		}
	}
	return tx.Commit(ctx)
}
