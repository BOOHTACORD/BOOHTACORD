package ownsessionpostgres

import (
	"context"
	"crypto/sha256"

	"github.com/jackc/pgx/v5/pgxpool"
	ownsessions "voice-platform/backend/internal/identity/list_own_sessions"
	"voice-platform/backend/internal/identity/session"
)

type Repository struct{ pool *pgxpool.Pool }

func New(pool *pgxpool.Pool) Repository { return Repository{pool: pool} }

func (r Repository) Read(ctx context.Context, owner string, current [sha256.Size]byte, cursor string) (ownsessions.Page, error) {
	page := ownsessions.Page{AccountID: owner, Sessions: []ownsessions.Session{}}
	var after any
	if cursor != "" {
		after = cursor
	}
	rows, err := r.pool.Query(ctx, `SELECT public_id::text,label,created_at,last_active_at,token_digest=$2
	    FROM sessions WHERE user_id=$1::uuid AND revoked_at IS NULL
	    AND expires_at>now() AND last_active_at>now()-($4::double precision * interval '1 second')
        AND ($3::uuid IS NULL OR (created_at,public_id)<(
            SELECT created_at,public_id FROM sessions WHERE public_id=$3::uuid AND user_id=$1::uuid))
	    ORDER BY created_at DESC,public_id DESC LIMIT 101`, owner, current[:], after, int64(session.IdleLifetime.Seconds()))
	if err != nil {
		return page, err
	}
	defer rows.Close()
	for rows.Next() {
		var item ownsessions.Session
		if err = rows.Scan(&item.ID, &item.Label, &item.CreatedAt, &item.LastActiveAt, &item.Current); err != nil {
			return page, err
		}
		page.Sessions = append(page.Sessions, item)
	}
	if err = rows.Err(); err != nil {
		return page, err
	}
	if len(page.Sessions) > 100 {
		page.Sessions = page.Sessions[:100]
		next := page.Sessions[99].ID
		page.NextCursor = &next
	}
	return page, nil
}
