package issuelivekitcredentialpostgres

import (
	"context"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	issuelivekitcredential "voice-platform/backend/internal/media/issue_livekit_credential"
)

const selectActiveLease = `
SELECT lease.id::text, lease.channel_id::text, account.display_name,
 COALESCE(sound.id::text,''), COALESCE(sound.revision::text,'')
FROM voice_leases AS lease
JOIN channels AS channel ON channel.id = lease.channel_id
JOIN sessions AS session ON session.token_digest = lease.session_token_digest
JOIN users AS account ON account.id = lease.user_id
LEFT JOIN join_sounds AS sound ON sound.account_id=account.id AND sound.enabled=true AND sound.id IS NOT NULL
WHERE lease.id = $1 AND lease.user_id = $2 AND lease.session_token_digest = $3 AND lease.revoked_at IS NULL
  AND channel.kind = 'VOICE' AND channel.archived_at IS NULL AND channel.admission_closed_at IS NULL
  AND session.revoked_at IS NULL AND account.blocked_at IS NULL
  AND NOT EXISTS(SELECT 1 FROM voice_timeouts restriction
      WHERE restriction.user_id=account.id AND restriction.expires_at>clock_timestamp())`

type Row interface{ Scan(...any) error }
type Database interface {
	QueryRow(context.Context, string, ...any) Row
}
type Repository struct{ database Database }

func New(database Database) Repository { return Repository{database: database} }
func (repository Repository) FindActive(context context.Context, input issuelivekitcredential.Input) (issuelivekitcredential.Lease, error) {
	var lease issuelivekitcredential.Lease
	err := repository.database.QueryRow(context, selectActiveLease, input.LeaseID, input.ActorID, input.SessionDigest[:]).Scan(&lease.ID, &lease.ChannelID, &lease.DisplayName, &lease.JoinSoundID, &lease.JoinSoundRevision)
	if errors.Is(err, pgx.ErrNoRows) {
		return issuelivekitcredential.Lease{}, issuelivekitcredential.ErrLeaseUnavailable
	}
	if err != nil {
		return issuelivekitcredential.Lease{}, fmt.Errorf("select active voice lease: %w", err)
	}
	return lease, nil
}
