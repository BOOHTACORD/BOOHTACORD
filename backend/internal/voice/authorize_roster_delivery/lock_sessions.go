package authorizerosterdelivery

import (
	"context"
	"time"

	"github.com/jackc/pgx/v5"
	"voice-platform/backend/internal/identity/session"
)

func lockParticipantSessions(ctx context.Context, tx pgx.Tx, digests [][]byte) (time.Time, error) {
	if len(digests) == 0 {
		return time.Time{}, nil
	}
	started := time.Now()
	rows, err := tx.Query(ctx, `SELECT EXTRACT(EPOCH FROM LEAST(expires_at, last_active_at + ($2::double precision * interval '1 second')) - clock_timestamp()) FROM sessions WHERE token_digest=ANY($1::bytea[]) ORDER BY token_digest FOR SHARE`, digests, int64(session.IdleLifetime.Seconds()))
	if err != nil {
		return time.Time{}, err
	}
	defer rows.Close()
	var earliest time.Time
	for rows.Next() {
		var seconds float64
		if err := rows.Scan(&seconds); err != nil {
			return time.Time{}, err
		}
		deadline := started.Add(time.Duration(seconds * float64(time.Second)))
		if !deadline.After(time.Now()) {
			return time.Time{}, ErrStale
		}
		if earliest.IsZero() || deadline.Before(earliest) {
			earliest = deadline
		}
	}
	return earliest, rows.Err()
}
