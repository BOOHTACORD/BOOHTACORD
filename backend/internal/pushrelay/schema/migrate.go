package relayschema

import (
	"context"
	_ "embed"
	"github.com/jackc/pgx/v5"
	"time"
)

//go:embed 001.sql
var source string

type Database interface {
	BeginTx(context.Context, pgx.TxOptions) (pgx.Tx, error)
}

func Migrate(ctx context.Context, database Database) error {
	tx, err := database.BeginTx(ctx, pgx.TxOptions{})
	if err != nil {
		return err
	}
	defer func() {
		end, cancel := context.WithTimeout(context.Background(), time.Second)
		defer cancel()
		_ = tx.Rollback(end)
	}()
	if _, err = tx.Exec(ctx, `SELECT pg_advisory_xact_lock(hashtextextended('notification-relay-schema/v1',0))`); err != nil {
		return err
	}
	if _, err = tx.Exec(ctx, `CREATE TABLE IF NOT EXISTS relay_schema_version(version integer PRIMARY KEY CHECK(version=1))`); err != nil {
		return err
	}
	var exists bool
	if err = tx.QueryRow(ctx, `SELECT EXISTS(SELECT 1 FROM relay_schema_version WHERE version=1)`).Scan(&exists); err != nil {
		return err
	}
	if !exists {
		if _, err = tx.Exec(ctx, source); err != nil {
			return err
		}
		if _, err = tx.Exec(ctx, `INSERT INTO relay_schema_version(version)VALUES(1)`); err != nil {
			return err
		}
	}
	return tx.Commit(ctx)
}
