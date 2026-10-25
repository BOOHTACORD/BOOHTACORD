package dispatchjob

import (
	"context"
	"errors"
	"github.com/jackc/pgx/v5"
	"time"
	"voice-platform/backend/internal/notifications/secretbox"
	provider "voice-platform/backend/internal/pushrelay/fcm_provider"
)

var ErrLostLease = errors.New("relay delivery claim no longer owned")

type Database interface {
	BeginTx(context.Context, pgx.TxOptions) (pgx.Tx, error)
}
type Store struct {
	Database  Database
	Box       *secretbox.Box
	Namespace string
	Platforms map[string]bool
}
type Job struct {
	ID, DeviceID, GrantID, Kind, LeaseOwner, Reference string
	Epoch                                              int64
	Attempts                                           int
	Cipher                                             []byte
	ExpiresAt                                          time.Time
	StartedAt                                          *time.Time
}
type Work struct {
	Job     Job
	Message provider.Message
}

func rollback(tx pgx.Tx) {
	ctx, cancel := context.WithTimeout(context.Background(), time.Second)
	defer cancel()
	_ = tx.Rollback(ctx)
}
func terminal(ctx context.Context, tx pgx.Tx, j Job, state, namespace string) error {
	changed, err := tx.Exec(ctx, `UPDATE relay_jobs SET state=$3,lease_owner=NULL,lease_until=NULL WHERE id=$1::uuid AND lease_owner=$2::uuid AND state='claimed'`, j.ID, j.LeaseOwner, state)
	if err != nil {
		return err
	}
	if changed.RowsAffected() != 1 {
		return ErrLostLease
	}
	if _, err = tx.Exec(ctx, `UPDATE relay_policy SET pending=pending-1 WHERE singleton`); err != nil {
		return err
	}
	_, err = tx.Exec(ctx, `INSERT INTO relay_counters(outcome,namespace,value)VALUES($1,$2,1)ON CONFLICT(outcome,namespace)DO UPDATE SET value=relay_counters.value+1`, state, namespace)
	return err
}
