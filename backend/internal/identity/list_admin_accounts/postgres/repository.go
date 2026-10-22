package adminaccountlistpostgres

import (
	"context"
	"fmt"

	"voice-platform/backend/internal/identity/list_admin_accounts"
)

const listAccounts = `
SELECT id::text, login, display_name, role, blocked_at IS NOT NULL, created_at, updated_at
FROM users
WHERE NOT EXISTS(SELECT 1 FROM support_product_identity WHERE account_id=users.id) AND ($1::uuid IS NULL OR id > $1::uuid)
ORDER BY id ASC LIMIT $2`

type Rows interface {
	Next() bool
	Scan(...any) error
	Err() error
	Close()
}
type Database interface {
	Query(context.Context, string, ...any) (Rows, error)
}
type Repository struct{ database Database }

func New(database Database) Repository { return Repository{database: database} }

func (repository Repository) List(ctx context.Context, cursor string, limit int) ([]listadminaccounts.Account, error) {
	var after any
	if cursor != "" {
		after = cursor
	}
	rows, err := repository.database.Query(ctx, listAccounts, after, limit)
	if err != nil {
		return nil, fmt.Errorf("query admin accounts: %w", err)
	}
	defer rows.Close()
	var accounts []listadminaccounts.Account
	for rows.Next() {
		var account listadminaccounts.Account
		if err := rows.Scan(&account.ID, &account.Login, &account.DisplayName, &account.Role, &account.Blocked, &account.CreatedAt, &account.UpdatedAt); err != nil {
			return nil, fmt.Errorf("scan admin account: %w", err)
		}
		accounts = append(accounts, account)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterate admin accounts: %w", err)
	}
	return accounts, nil
}
