package listconnectedparticipantspostgres

import (
	"context"
	"fmt"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgtype"
	identitysession "voice-platform/backend/internal/identity/session"
	listconnectedparticipants "voice-platform/backend/internal/voice/list_connected_participants"
)

const selectVisible = `
SELECT channel.id::text, roster.lease_id::text, roster.account_id::text, roster.display_name
FROM channels AS channel
JOIN users AS actor ON actor.id = $1::uuid AND actor.blocked_at IS NULL
LEFT JOIN LATERAL (
    SELECT lease.id AS lease_id, account.id AS account_id, account.display_name
    FROM voice_leases AS lease
    JOIN sessions AS session ON session.token_digest = lease.session_token_digest
        AND session.user_id = lease.user_id AND session.revoked_at IS NULL
        AND session.expires_at > clock_timestamp()
        AND session.last_active_at > clock_timestamp() - ($2::double precision * interval '1 second')
    JOIN users AS account ON account.id = lease.user_id AND account.blocked_at IS NULL
    WHERE lease.channel_id = channel.id AND lease.revoked_at IS NULL
) AS roster ON TRUE
WHERE channel.kind = 'VOICE' AND channel.archived_at IS NULL
ORDER BY channel.id, roster.lease_id`

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

func (repository Repository) ListVisible(ctx context.Context, actorID string) ([]listconnectedparticipants.Channel, error) {
	if uuid.Validate(actorID) != nil {
		return nil, fmt.Errorf("invalid roster actor")
	}
	rows, err := repository.database.Query(ctx, selectVisible, actorID, int64(identitysession.IdleLifetime.Seconds()))
	if err != nil {
		return nil, fmt.Errorf("select visible voice roster: %w", err)
	}
	defer rows.Close()
	channels := make([]listconnectedparticipants.Channel, 0)
	for rows.Next() {
		var channelID string
		var leaseID, accountID, displayName pgtype.Text
		if err := rows.Scan(&channelID, &leaseID, &accountID, &displayName); err != nil {
			return nil, fmt.Errorf("scan visible voice roster: %w", err)
		}
		if len(channels) == 0 || channels[len(channels)-1].ID != channelID {
			channels = append(channels, listconnectedparticipants.Channel{ID: channelID})
		}
		if leaseID.Valid && accountID.Valid && displayName.Valid {
			last := &channels[len(channels)-1]
			last.Leases = append(last.Leases, listconnectedparticipants.Lease{
				ID: leaseID.String, AccountID: accountID.String, DisplayName: displayName.String,
			})
		}
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterate visible voice roster: %w", err)
	}
	return channels, nil
}
