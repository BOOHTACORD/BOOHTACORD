package sessionpostgres

import (
	"context"
	"crypto/sha256"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	"voice-platform/backend/internal/identity/authenticate_session"
	"voice-platform/backend/internal/identity/session"
)

const selectActivePrincipal = `
WITH active AS MATERIALIZED (
SELECT u.id::text, u.role, u.display_name, s.expires_at
FROM sessions s
JOIN users u ON u.id = s.user_id
WHERE s.token_digest = $1
  AND s.revoked_at IS NULL
  AND s.expires_at > now()
  AND s.last_active_at > now() - ($2::double precision * interval '1 second')
  AND u.blocked_at IS NULL
  AND NOT EXISTS(SELECT 1 FROM support_product_identity WHERE account_id=u.id)
), touched AS (
 UPDATE sessions SET last_active_at=now()
 WHERE token_digest=$1 AND EXISTS(SELECT 1 FROM active)
   AND last_active_at < now() - interval '60 seconds'
)
SELECT id,role,display_name,expires_at FROM active`

type Row interface {
	Scan(...any) error
}

type Database interface {
	QueryRow(context.Context, string, ...any) Row
}

type Repository struct {
	database Database
}

func New(database Database) Repository {
	return Repository{database: database}
}

func (repository Repository) FindActive(context context.Context, digest [sha256.Size]byte) (authenticatesession.Principal, error) {
	var principal authenticatesession.Principal
	err := repository.database.QueryRow(context, selectActivePrincipal, digest[:], int64(session.IdleLifetime.Seconds())).Scan(&principal.AccountID, &principal.Role, &principal.DisplayName, &principal.ExpiresAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return authenticatesession.Principal{}, authenticatesession.ErrSessionNotFound
	}
	if err != nil {
		return authenticatesession.Principal{}, fmt.Errorf("select active session: %w", err)
	}
	return principal, nil
}
