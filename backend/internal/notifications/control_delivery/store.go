package controldelivery

import (
	"context"
	"github.com/jackc/pgx/v5"
	"time"
)

type Database interface {
	BeginTx(context.Context, pgx.TxOptions) (pgx.Tx, error)
}
type Store struct{ database Database }

func New(database Database) Store                                 { return Store{database} }
func (s Store) Configure(ctx context.Context, enabled bool) error { return s.set(ctx, &enabled, nil) }
func (s Store) Kill(ctx context.Context, disabled bool) error     { return s.set(ctx, nil, &disabled) }
func (s Store) set(ctx context.Context, configured, kill *bool) error {
	ctx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()
	tx, err := s.database.BeginTx(ctx, pgx.TxOptions{})
	if err != nil {
		return err
	}
	defer func() {
		cleanup, cancel := context.WithTimeout(context.Background(), time.Second)
		defer cancel()
		_ = tx.Rollback(cleanup)
	}()
	var oldEnabled, oldKill bool
	if err = tx.QueryRow(ctx, `SELECT operator_enabled,kill_switch FROM notification_runtime_policy WHERE singleton FOR UPDATE`).Scan(&oldEnabled, &oldKill); err != nil {
		return err
	}
	enabled, disabled := oldEnabled, oldKill
	if configured != nil {
		enabled = *configured
	}
	if kill != nil {
		disabled = *kill
	}
	if enabled == oldEnabled && disabled == oldKill {
		return tx.Commit(ctx)
	}
	for _, query := range []string{
		`UPDATE notification_outbox SET state='suppressed',reason='operator_disabled',lease_owner=NULL,lease_until=NULL WHERE state IN('pending','planning')`,
		`UPDATE notification_deliveries SET state='suppressed',reason='operator_disabled',lease_owner=NULL,lease_until=NULL WHERE state IN('pending','claimed','retry')`,
		`UPDATE notification_groups SET reservation_job=NULL,reservation_until=NULL`,
	} {
		if _, err = tx.Exec(ctx, query); err != nil {
			return err
		}
	}
	if _, err = tx.Exec(ctx, `UPDATE notification_runtime_policy SET operator_enabled=$1,kill_switch=$2,epoch=epoch+1,intent_pending=0,delivery_pending=0 WHERE singleton`, enabled, disabled); err != nil {
		return err
	}
	return tx.Commit(ctx)
}
