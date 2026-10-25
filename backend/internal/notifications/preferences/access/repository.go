package preferencesaccess

import (
	"context"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	p "voice-platform/backend/internal/notifications/preferences"
)

type Database interface {
	QueryRow(context.Context, string, ...any) pgx.Row
}
type Repository struct{ database Database }

func New(database Database) Repository { return Repository{database} }

const activeActor = `EXISTS(SELECT 1 FROM users WHERE id=$2::uuid AND blocked_at IS NULL)`
const channelAccess = `SELECT EXISTS(SELECT 1 FROM channels WHERE id=$1::uuid AND kind='TEXT' AND archived_at IS NULL) AND ` + activeActor
const pairAccess = `SELECT EXISTS(
 SELECT 1 FROM direct_messages dm
 JOIN users one ON one.id=dm.participant_one_id
 JOIN users two ON two.id=dm.participant_two_id
 WHERE dm.id=$1::uuid AND $2::uuid IN(dm.participant_one_id,dm.participant_two_id)
 AND one.blocked_at IS NULL AND two.blocked_at IS NULL) AND ` + activeActor

// TEXT visibility follows list_text_messages; DM membership has no admin bypass.
func (r Repository) Allowed(ctx context.Context, actor string, override p.Override) (bool, error) {
	actorID, err := uuid.Parse(actor)
	if err != nil || actorID == uuid.Nil {
		return false, nil
	}
	id, err := uuid.Parse(override.ID)
	if err != nil || id == uuid.Nil {
		return false, nil
	}
	query := channelAccess
	switch override.Kind {
	case "CHANNEL":
	case "DIRECT_MESSAGE":
		query = pairAccess
	default:
		return false, nil
	}
	var allowed bool
	err = r.database.QueryRow(ctx, query, id.String(), actorID.String()).Scan(&allowed)
	return allowed, err
}
