package postgres

import (
	"context"
	"errors"
	"fmt"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	presence "voice-platform/backend/internal/media/screen_viewer_presence"
)

type Row interface{ Scan(...any) error }
type Rows interface {
	Next() bool
	Scan(...any) error
	Err() error
	Close()
}
type Database interface {
	QueryRow(context.Context, string, ...any) Row
}
type AudienceDatabase interface {
	Query(context.Context, string, ...any) (Rows, error)
}
type Authorizer struct {
	database Database
	audience AudienceDatabase
}

func New(database Database) Authorizer {
	authorizer := Authorizer{database: database}
	authorizer.audience, _ = database.(AudienceDatabase)
	return authorizer
}

func (authorizer Authorizer) AuthorizeOwner(ctx context.Context, principal presence.Principal, ownerLeaseID string) (string, string, error) {
	var channelID, ownerAccountID string
	err := authorizer.database.QueryRow(ctx, ownerAuthorization, ownerLeaseID, principal.AccountID, principal.SessionDigest[:]).Scan(&channelID, &ownerAccountID)
	channelID, ownerAccountID, _, err = authorizationResult(channelID, ownerAccountID, "", err)
	return channelID, ownerAccountID, err
}

func (authorizer Authorizer) AuthorizeViewer(ctx context.Context, principal presence.Principal, viewerLeaseID, ownerLeaseID string) (string, string, string, error) {
	var channelID, ownerAccountID, viewerAccountID string
	err := authorizer.database.QueryRow(ctx, viewerAuthorization, viewerLeaseID, ownerLeaseID, principal.AccountID, principal.SessionDigest[:]).Scan(&channelID, &ownerAccountID, &viewerAccountID)
	channelID, ownerAccountID, viewerAccountID, err = authorizationResult(channelID, ownerAccountID, viewerAccountID, err)
	return channelID, ownerAccountID, viewerAccountID, err
}

func (authorizer Authorizer) ActiveWatchers(ctx context.Context, ownerLeaseID string, viewerLeaseIDs []string) ([]presence.Watcher, error) {
	if authorizer.audience == nil || len(viewerLeaseIDs) == 0 {
		return nil, presence.ErrUnavailable
	}
	ids := make([]uuid.UUID, 0, len(viewerLeaseIDs))
	for _, id := range viewerLeaseIDs {
		parsed, err := uuid.Parse(id)
		if err != nil {
			return nil, presence.ErrDenied
		}
		ids = append(ids, parsed)
	}
	rows, err := authorizer.audience.Query(ctx, activeWatchers, ownerLeaseID, ids)
	if err != nil {
		return nil, presence.ErrUnavailable
	}
	defer rows.Close()
	watchers := make([]presence.Watcher, 0, len(viewerLeaseIDs))
	for rows.Next() {
		var watcher presence.Watcher
		if err := rows.Scan(&watcher.LeaseID, &watcher.AccountID); err != nil {
			return nil, presence.ErrUnavailable
		}
		watchers = append(watchers, watcher)
	}
	if rows.Err() != nil {
		return nil, presence.ErrUnavailable
	}
	return watchers, nil
}

func authorizationResult(channelID, ownerAccountID, viewerAccountID string, err error) (string, string, string, error) {
	if errors.Is(err, pgx.ErrNoRows) {
		return "", "", "", presence.ErrDenied
	}
	if err != nil {
		return "", "", "", fmt.Errorf("authorize screen viewer presence: %w", presence.ErrUnavailable)
	}
	return channelID, ownerAccountID, viewerAccountID, nil
}

const ownerAuthorization = `
SELECT owner.channel_id::text, owner.user_id::text
FROM voice_leases AS owner
JOIN sessions AS owner_session ON owner_session.token_digest = owner.session_token_digest AND owner_session.user_id = owner.user_id
JOIN channels AS channel ON channel.id = owner.channel_id
JOIN users AS owner_account ON owner_account.id = owner.user_id
WHERE owner.id = $1 AND owner.user_id = $2 AND owner.session_token_digest = $3
  AND owner.revoked_at IS NULL AND owner_session.revoked_at IS NULL
  AND channel.kind = 'VOICE' AND channel.archived_at IS NULL AND channel.admission_closed_at IS NULL
  AND owner_account.blocked_at IS NULL`

const viewerAuthorization = `
SELECT owner.channel_id::text, owner.user_id::text, viewer.user_id::text
FROM voice_leases AS viewer
JOIN sessions AS viewer_session ON viewer_session.token_digest = viewer.session_token_digest AND viewer_session.user_id = viewer.user_id
JOIN users AS viewer_account ON viewer_account.id = viewer.user_id
JOIN voice_leases AS owner ON owner.id = $2
JOIN sessions AS owner_session ON owner_session.token_digest = owner.session_token_digest AND owner_session.user_id = owner.user_id
JOIN users AS owner_account ON owner_account.id = owner.user_id
JOIN channels AS channel ON channel.id = owner.channel_id
WHERE viewer.id = $1 AND viewer.user_id = $3 AND viewer.session_token_digest = $4
  AND viewer.channel_id = owner.channel_id
  AND viewer.revoked_at IS NULL AND viewer_session.revoked_at IS NULL
  AND owner.revoked_at IS NULL AND owner_session.revoked_at IS NULL
  AND channel.kind = 'VOICE' AND channel.archived_at IS NULL AND channel.admission_closed_at IS NULL
  AND owner_account.blocked_at IS NULL AND viewer_account.blocked_at IS NULL`
