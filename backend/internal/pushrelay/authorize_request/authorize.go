package authorizerequest

import (
	"context"
	"crypto/ed25519"
	"errors"
	"github.com/jackc/pgx/v5"
	"time"
	signature "voice-platform/backend/internal/pushrelay/request_signature"
)

var ErrDenied = errors.New("relay authorization denied")
var ErrLimit = errors.New("relay capacity unavailable")

type Policy struct {
	Enabled             bool
	Epoch               int64
	Pending, MaxPending int
}

func Lock(ctx context.Context, tx pgx.Tx) (Policy, error) {
	var p Policy
	err := tx.QueryRow(ctx, `SELECT enabled AND NOT kill_switch,epoch,pending,max_pending FROM relay_policy WHERE singleton FOR UPDATE`).Scan(&p.Enabled, &p.Epoch, &p.Pending, &p.MaxPending)
	return p, err
}
func Verify(ctx context.Context, tx pgx.Tx, r signature.Request, role string, pending bool, now time.Time) error {
	if _, err := signature.Canonical(r); err != nil {
		return ErrDenied
	}
	if r.Role != role {
		return ErrDenied
	}
	var key []byte
	var err error
	if role == "device" {
		err = tx.QueryRow(ctx, `SELECT public_key FROM relay_devices WHERE id=$1::uuid AND expires_at>$2 AND(state='active' OR($3 AND state='pending')) FOR SHARE`, r.Subject, now, pending).Scan(&key)
	} else if role == "tenant" {
		err = tx.QueryRow(ctx, `SELECT public_key FROM relay_tenants WHERE id=$1::uuid FOR SHARE`, r.Subject).Scan(&key)
	} else {
		return ErrDenied
	}
	if errors.Is(err, pgx.ErrNoRows) {
		return ErrDenied
	}
	if err != nil {
		return err
	}
	if signature.Verify(ed25519.PublicKey(key), r, now) != nil {
		return ErrDenied
	}
	if _, err = tx.Exec(ctx, `DELETE FROM relay_replays WHERE(role,subject,nonce)IN(SELECT role,subject,nonce FROM relay_replays WHERE expires_at<$1 LIMIT 64)`, now); err != nil {
		return err
	}
	changed, err := tx.Exec(ctx, `INSERT INTO relay_replays(role,subject,nonce,expires_at) SELECT $1,$2::uuid,$3::uuid,$4::timestamptz+interval '2 minutes'
 WHERE(SELECT count(*)FROM relay_replays)<10000 ON CONFLICT DO NOTHING`, role, r.Subject, r.Nonce, now)
	if err != nil {
		return err
	}
	if changed.RowsAffected() != 1 {
		return ErrDenied
	}
	return nil
}
func Budget(ctx context.Context, tx pgx.Tx, scope, subject string, limit int, now time.Time) (bool, error) {
	if scope != "source" && scope != "tenant" && scope != "device" && scope != "global" || len(subject) > 64 || limit < 1 || limit > 1000 {
		return false, ErrDenied
	}
	if _, err := tx.Exec(ctx, `DELETE FROM relay_budgets WHERE(scope,subject)IN(SELECT scope,subject FROM relay_budgets WHERE window_start<$1::timestamptz-interval '1 hour' LIMIT 16)`, now); err != nil {
		return false, err
	}
	var attempts int
	err := tx.QueryRow(ctx, `INSERT INTO relay_budgets(scope,subject,window_start,attempts)
 SELECT $1,$2,date_trunc('minute',$3::timestamptz),1 WHERE(SELECT count(*)FROM relay_budgets)<10000 OR EXISTS(SELECT 1 FROM relay_budgets WHERE scope=$1 AND subject=$2)
 ON CONFLICT(scope,subject)DO UPDATE SET window_start=GREATEST(relay_budgets.window_start,EXCLUDED.window_start),
 attempts=CASE WHEN relay_budgets.window_start>=EXCLUDED.window_start THEN LEAST(relay_budgets.attempts+1,1001)ELSE 1 END RETURNING attempts`, scope, subject, now).Scan(&attempts)
	if errors.Is(err, pgx.ErrNoRows) {
		return false, nil
	}
	if err != nil {
		return false, err
	}
	return attempts <= limit, nil
}
