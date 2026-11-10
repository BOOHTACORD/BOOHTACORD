package serializesessiondelivery

import (
	"context"
	"errors"
	"time"

	"github.com/jackc/pgx/v5"
	auth "voice-platform/backend/internal/identity/authenticate_session"
	"voice-platform/backend/internal/identity/session"
)

const activeSession = `
SELECT EXTRACT(EPOCH FROM LEAST(s.expires_at,
 s.last_active_at + ($3::double precision * interval '1 second')) - clock_timestamp())
FROM sessions s JOIN users u ON u.id=s.user_id
WHERE s.token_digest=$1 AND u.id=$2::uuid AND u.role=$4
 AND s.revoked_at IS NULL AND u.blocked_at IS NULL
 AND s.expires_at > clock_timestamp()
 AND s.last_active_at > clock_timestamp() - ($3::double precision * interval '1 second')
 AND NOT EXISTS(SELECT 1 FROM support_product_identity WHERE account_id=u.id)
FOR SHARE OF s,u`

func lockActiveSession(ctx context.Context, tx pgx.Tx, principal auth.Principal) (time.Duration, error) {
	var singleton bool
	if err := tx.QueryRow(ctx, `SELECT singleton FROM support_product_identity WHERE singleton=true FOR KEY SHARE`).Scan(&singleton); err != nil || !singleton {
		return 0, ErrUnavailable
	}
	var seconds float64
	started := time.Now()
	err := tx.QueryRow(ctx, activeSession, principal.SessionDigest[:], principal.AccountID,
		int64(session.IdleLifetime.Seconds()), principal.Role).Scan(&seconds)
	if errors.Is(err, pgx.ErrNoRows) {
		return 0, ErrSession
	}
	if err != nil || seconds <= 0 || ctx.Err() != nil {
		return 0, ErrUnavailable
	}
	ttl := time.Duration(seconds*float64(time.Second)) - time.Since(started)
	if ttl <= 0 {
		return 0, ErrSession
	}
	return ttl, nil
}
