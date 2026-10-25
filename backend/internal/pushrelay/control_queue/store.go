package controlqueue

import (
	"context"
	"github.com/jackc/pgx/v5"
	"time"
)

type Database interface {
	BeginTx(context.Context, pgx.TxOptions) (pgx.Tx, error)
}
type Store struct{ Database Database }

func (s Store) Configure(ctx context.Context, enabled bool) error { return s.set(ctx, &enabled, nil) }
func (s Store) Kill(ctx context.Context, disabled bool) error     { return s.set(ctx, nil, &disabled) }
func (s Store) set(ctx context.Context, configured, kill *bool) error {
	ctx, cancel := context.WithTimeout(ctx, 5*time.Second)
	defer cancel()
	tx, err := s.Database.BeginTx(ctx, pgx.TxOptions{})
	if err != nil {
		return err
	}
	defer rollback(tx)
	var oldEnabled, oldKill bool
	if err = tx.QueryRow(ctx, `SELECT enabled,kill_switch FROM relay_policy WHERE singleton FOR UPDATE`).Scan(&oldEnabled, &oldKill); err != nil {
		return err
	}
	enabled, disabled := oldEnabled, oldKill
	if configured != nil {
		enabled = *configured
	}
	if kill != nil {
		disabled = *kill
	}
	if oldEnabled == enabled && oldKill == disabled {
		return tx.Commit(ctx)
	}
	if _, err = tx.Exec(ctx, `WITH changed AS(UPDATE relay_jobs SET state='revoked',lease_owner=NULL,lease_until=NULL WHERE state IN('pending','claimed','retry') RETURNING device_id)
 INSERT INTO relay_counters(outcome,namespace,value) SELECT 'revoked',d.namespace,count(*) FROM changed c JOIN relay_devices d ON d.id=c.device_id GROUP BY d.namespace
 ON CONFLICT(outcome,namespace)DO UPDATE SET value=relay_counters.value+EXCLUDED.value`); err != nil {
		return err
	}
	if _, err = tx.Exec(ctx, `UPDATE relay_policy SET enabled=$1,kill_switch=$2,epoch=epoch+1,pending=0 WHERE singleton`, enabled, disabled); err != nil {
		return err
	}
	return tx.Commit(ctx)
}
func rollback(tx pgx.Tx) {
	ctx, cancel := context.WithTimeout(context.Background(), time.Second)
	defer cancel()
	_ = tx.Rollback(ctx)
}
