package soundstore

import (
	"context"
	"errors"
	"github.com/jackc/pgx/v5"
	s "voice-platform/backend/internal/voice/join_sound"
)

const ownerGuard = `account_id=$1 AND EXISTS(SELECT 1 FROM users WHERE id=$1 AND blocked_at IS NULL)
 AND EXISTS(SELECT 1 FROM sessions WHERE user_id=$1 AND token_digest=$2 AND revoked_at IS NULL AND expires_at>now())`

func (r Repository) Current(ctx context.Context, a s.Actor) (s.Sound, error) {
	return scan(r.db.QueryRow(ctx, `SELECT id,account_id,revision,enabled,payload,duration_ms FROM join_sounds WHERE id IS NOT NULL AND `+ownerGuard, a.Account, a.SessionDigest[:]))
}
func (r Repository) Enable(ctx context.Context, a s.Actor, enabled bool) (s.Sound, error) {
	return scan(r.db.QueryRow(ctx, `UPDATE join_sounds SET enabled=$3,revision=revision+1 WHERE id IS NOT NULL AND `+ownerGuard+` RETURNING id,account_id,revision,enabled,payload,duration_ms`, a.Account, a.SessionDigest[:], enabled))
}
func (r Repository) Delete(ctx context.Context, a s.Actor) error {
	var revision int64
	err := r.db.QueryRow(ctx, `UPDATE join_sounds SET id=NULL,payload=NULL,duration_ms=NULL,enabled=false,revision=revision+1 WHERE `+ownerGuard+` RETURNING revision`, a.Account, a.SessionDigest[:]).Scan(&revision)
	if errors.Is(err, pgx.ErrNoRows) {
		return s.ErrNotFound
	}
	return err
}
