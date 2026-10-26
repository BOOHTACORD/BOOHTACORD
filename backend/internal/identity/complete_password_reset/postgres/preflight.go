package resetpostgres

import (
	"context"
	"crypto/sha256"
	"errors"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5"
	reset "voice-platform/backend/internal/identity/complete_password_reset"
)

const selectEligibleReset = `
SELECT 1 FROM password_resets
WHERE token_digest = $1 AND used_at IS NULL AND expires_at > now()`

// Preflight is an autocommit read on the pool: no row lock or transaction spans
// Argon2. A successful read is advisory; Consume rechecks expiry and one-use
// state in its existing atomic password/revocation/outbox/audit statement.
func (repository Repository) Preflight(ctx context.Context, digest [sha256.Size]byte) error {
	if err := ctx.Err(); err != nil {
		return err
	}
	ctx, cancel := context.WithTimeout(ctx, 2*time.Second)
	defer cancel()
	var eligible int
	err := repository.database.QueryRow(ctx, selectEligibleReset, digest[:]).Scan(&eligible)
	if errors.Is(err, pgx.ErrNoRows) {
		return reset.ErrResetNotFound
	}
	if err != nil {
		return fmt.Errorf("select eligible password reset: %w", err)
	}
	return nil
}
