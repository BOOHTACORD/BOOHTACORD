package listdirectmessagecandidatespostgres

import (
	"context"
	"fmt"

	listdirectmessagecandidates "voice-platform/backend/internal/chat/list_direct_message_candidates"
)

const selectDirectMessageCandidates = `
SELECT id::text, display_name
FROM users
WHERE id <> $1::uuid
  AND blocked_at IS NULL
  AND NOT EXISTS(SELECT 1 FROM support_product_identity WHERE account_id=users.id)
  AND ($2::uuid IS NULL OR id > $2::uuid)
ORDER BY id ASC
LIMIT ($3::int + 1)`

type Rows interface {
	Next() bool
	Scan(...any) error
	Close()
	Err() error
}
type Database interface {
	Query(context.Context, string, ...any) (Rows, error)
}
type Repository struct{ database Database }

func New(database Database) Repository { return Repository{database: database} }

func (repository Repository) List(context context.Context, request listdirectmessagecandidates.Request) ([]listdirectmessagecandidates.Candidate, error) {
	var after any
	if request.After != "" {
		after = request.After
	}
	rows, err := repository.database.Query(context, selectDirectMessageCandidates, request.ActorID, after, request.Limit)
	if err != nil {
		return nil, fmt.Errorf("select direct message candidates: %w", err)
	}
	defer rows.Close()
	result := make([]listdirectmessagecandidates.Candidate, 0)
	for rows.Next() {
		var candidate listdirectmessagecandidates.Candidate
		if err := rows.Scan(&candidate.ID, &candidate.DisplayName); err != nil {
			return nil, fmt.Errorf("scan direct message candidate: %w", err)
		}
		result = append(result, candidate)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterate direct message candidates: %w", err)
	}
	return result, nil
}
