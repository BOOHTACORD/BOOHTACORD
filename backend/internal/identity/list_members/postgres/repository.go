package memberpostgres

import (
	"context"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	"voice-platform/backend/internal/identity/list_members"
)

const listMembers = `
SELECT id::text, login, display_name, role, avatar_key IS NOT NULL, profile_revision
FROM users
WHERE blocked_at IS NULL AND NOT EXISTS(SELECT 1 FROM support_product_identity WHERE account_id=users.id) AND ($1::uuid IS NULL OR id > $1::uuid)
ORDER BY id ASC LIMIT $2`
const findMember = `SELECT id::text, login, display_name, role, avatar_key IS NOT NULL, profile_revision FROM users WHERE id = $1 AND blocked_at IS NULL AND NOT EXISTS(SELECT 1 FROM support_product_identity WHERE account_id=users.id)`

type Rows interface {
	Next() bool
	Scan(...any) error
	Err() error
	Close()
}
type Row = pgx.Row
type Database interface {
	Query(context.Context, string, ...any) (Rows, error)
	QueryRow(context.Context, string, ...any) Row
}
type Repository struct{ database Database }

func New(database Database) Repository { return Repository{database: database} }

func (repository Repository) List(ctx context.Context, cursor string, limit int) ([]listmembers.Member, error) {
	var after any
	if cursor != "" {
		after = cursor
	}
	rows, err := repository.database.Query(ctx, listMembers, after, limit)
	if err != nil {
		return nil, fmt.Errorf("query members: %w", err)
	}
	defer rows.Close()
	var members []listmembers.Member
	for rows.Next() {
		var member listmembers.Member
		if err := rows.Scan(&member.ID, &member.Login, &member.DisplayName, &member.Role, &member.HasAvatar, &member.Revision); err != nil {
			return nil, fmt.Errorf("scan member: %w", err)
		}
		members = append(members, member)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterate members: %w", err)
	}
	return members, nil
}

func (repository Repository) Find(ctx context.Context, memberID string) (listmembers.Member, error) {
	var member listmembers.Member
	err := repository.database.QueryRow(ctx, findMember, memberID).Scan(&member.ID, &member.Login, &member.DisplayName, &member.Role, &member.HasAvatar, &member.Revision)
	if errors.Is(err, pgx.ErrNoRows) {
		return listmembers.Member{}, listmembers.ErrMemberNotFound
	}
	if err != nil {
		return listmembers.Member{}, fmt.Errorf("select member: %w", err)
	}
	return member, nil
}
