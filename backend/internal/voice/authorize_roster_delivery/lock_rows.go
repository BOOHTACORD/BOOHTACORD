package authorizerosterdelivery

import (
	"bytes"
	"context"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgtype"
)

func lockSnapshotRows(ctx context.Context, tx pgx.Tx, ids lockedIDs) (time.Time, error) {
	digests, err := leaseDigests(ctx, tx, ids.leases)
	if err != nil {
		return time.Time{}, err
	}
	if err := lockRows(ctx, tx, `SELECT id FROM users WHERE id=ANY($1::uuid[]) ORDER BY id FOR SHARE`, ids.accounts); err != nil {
		return time.Time{}, err
	}
	deadline, err := lockParticipantSessions(ctx, tx, digests)
	if err != nil {
		return time.Time{}, err
	}
	queries := []struct {
		sql  string
		args any
	}{
		{`SELECT id FROM voice_leases WHERE id=ANY($1::uuid[]) ORDER BY id FOR SHARE`, ids.leases},
		{`SELECT c.id FROM channels c JOIN categories cat ON cat.id=c.category_id WHERE c.id=ANY($1::uuid[]) ORDER BY c.id FOR SHARE OF c,cat`, ids.channels},
	}
	for _, query := range queries {
		if err := lockRows(ctx, tx, query.sql, query.args); err != nil {
			return time.Time{}, err
		}
	}
	lockedDigests, err := leaseDigests(ctx, tx, ids.leases)
	if err != nil {
		return time.Time{}, err
	}
	if len(lockedDigests) != len(digests) {
		return time.Time{}, ErrStale
	}
	for i := range digests {
		if !bytes.Equal(digests[i], lockedDigests[i]) {
			return time.Time{}, ErrStale
		}
	}
	return deadline, nil
}

func leaseDigests(ctx context.Context, tx pgx.Tx, ids []pgtype.UUID) ([][]byte, error) {
	if len(ids) == 0 {
		return nil, nil
	}
	rows, err := tx.Query(ctx, `SELECT session_token_digest FROM voice_leases WHERE id=ANY($1::uuid[]) ORDER BY id`, ids)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var digests [][]byte
	for rows.Next() {
		var digest []byte
		if err := rows.Scan(&digest); err != nil {
			return nil, err
		}
		digests = append(digests, digest)
	}
	return digests, rows.Err()
}

func lockRows(ctx context.Context, tx pgx.Tx, sql string, args any) error {
	rows, err := tx.Query(ctx, sql, args)
	if err != nil {
		return err
	}
	defer rows.Close()
	for rows.Next() {
	}
	return rows.Err()
}
