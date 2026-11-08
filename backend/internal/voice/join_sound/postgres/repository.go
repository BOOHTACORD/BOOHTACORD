package soundstore

import (
	"context"
	"errors"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	s "voice-platform/backend/internal/voice/join_sound"
)

type Database interface {
	QueryRow(context.Context, string, ...any) pgx.Row
}
type Repository struct{ db Database }

func New(db Database) Repository { return Repository{db} }
func (r Repository) Reserve(ctx context.Context, account string) (int64, error) {
	var revision int64
	err := r.db.QueryRow(ctx, reserveSQL, account).Scan(&revision)
	if errors.Is(err, pgx.ErrNoRows) {
		return 0, s.ErrRateLimited
	}
	return revision, err
}
func (r Repository) Replace(ctx context.Context, actor s.Actor, revision int64, audio s.Audio) (s.Sound, error) {
	return scan(r.db.QueryRow(ctx, replaceSQL, actor.Account, uuid.NewString(), audio.Bytes, audio.DurationMS, actor.SessionDigest[:], revision))
}
func (r Repository) Fetch(ctx context.Context, actor s.Actor, id string) (s.Sound, error) {
	return scan(r.db.QueryRow(ctx, fetchSQL, actor.Account, actor.SessionDigest[:], id))
}
func scan(row pgx.Row) (s.Sound, error) {
	var value s.Sound
	err := row.Scan(&value.ID, &value.Owner, &value.Revision, &value.Enabled, &value.Audio.Bytes, &value.Audio.DurationMS)
	if errors.Is(err, pgx.ErrNoRows) {
		return s.Sound{}, s.ErrNotFound
	}
	return value, err
}
