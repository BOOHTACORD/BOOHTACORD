package loginpostgres

import (
	"context"
	"crypto/sha256"
	"errors"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5"
	"voice-platform/backend/internal/identity/login_user"
)

const selectLoginAccount = `
SELECT id::text, login, password_hash, blocked_at IS NOT NULL
FROM users
WHERE login = $1 AND NOT EXISTS(SELECT 1 FROM support_product_identity WHERE account_id=users.id)`

const insertSession = `
INSERT INTO sessions (token_digest, user_id, expires_at)
VALUES ($1, $2, $3)`

type Row interface {
	Scan(...any) error
}

type Database interface {
	QueryRow(context.Context, string, ...any) Row
	Exec(context.Context, string, ...any) error
}

type Repository struct {
	database Database
}

func New(database Database) Repository {
	return Repository{database: database}
}

func (repository Repository) FindByLogin(context context.Context, login string) (loginuser.Account, error) {
	var account loginuser.Account
	err := repository.database.QueryRow(context, selectLoginAccount, login).Scan(
		&account.ID,
		&account.Login,
		&account.PasswordHash,
		&account.Blocked,
	)
	if errors.Is(err, pgx.ErrNoRows) {
		return loginuser.Account{}, loginuser.ErrAccountNotFound
	}
	if err != nil {
		return loginuser.Account{}, fmt.Errorf("select login account: %w", err)
	}
	return account, nil
}

func (repository Repository) Create(context context.Context, accountID string, digest [sha256.Size]byte, expiresAt time.Time) error {
	if err := repository.database.Exec(context, insertSession, digest[:], accountID, expiresAt); err != nil {
		return fmt.Errorf("insert session: %w", err)
	}
	return nil
}
