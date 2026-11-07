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
func (r Repository) Reserve(ctx context.Context, account string) (bool, error) {
	var allowed bool
	err := r.db.QueryRow(ctx, reserveSQL, account).Scan(&allowed)
	if errors.Is(err, pgx.ErrNoRows) {
		return false, nil
	}
	return allowed, err
}
func (r Repository) Replace(ctx context.Context, account string, audio s.Audio) (s.Sound, error) {
	return scan(r.db.QueryRow(ctx, replaceSQL, account, uuid.NewString(), audio.Bytes, audio.DurationMS))
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
