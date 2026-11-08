package soundpostgres

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"github.com/jackc/pgx/v5"
	p "voice-platform/backend/internal/voice/sound_preferences"
)

type Database interface {
	QueryRow(context.Context, string, ...any) pgx.Row
}
type Repository struct{ database Database }

func New(database Database) Repository { return Repository{database: database} }
func (r Repository) Read(ctx context.Context, id string) (p.Snapshot, error) {
	var revision int64
	var document []byte
	err := r.database.QueryRow(ctx, readSQL, id).Scan(&revision, &document)
	if errors.Is(err, pgx.ErrNoRows) {
		return p.Snapshot{Settings: p.Default()}, nil
	}
	if err != nil {
		return p.Snapshot{}, fmt.Errorf("read voice preferences: %w", err)
	}
	return decode(revision, document)
}
func (r Repository) CompareAndSwap(ctx context.Context, id string, revision int64, settings p.Settings) (p.Snapshot, error) {
	document, err := json.Marshal(settings)
	if err != nil {
		return p.Snapshot{}, err
	}
	var resultRevision int64
	var result []byte
	err = r.database.QueryRow(ctx, saveSQL, id, document, revision).Scan(&resultRevision, &result)
	if errors.Is(err, pgx.ErrNoRows) {
		return p.Snapshot{}, p.ErrConflict
	}
	if err != nil {
		return p.Snapshot{}, fmt.Errorf("save voice preferences: %w", err)
	}
	return decode(resultRevision, result)
}
func decode(revision int64, document []byte) (p.Snapshot, error) {
	var value p.Settings
	if err := json.Unmarshal(document, &value); err != nil {
		return p.Snapshot{}, fmt.Errorf("decode voice preferences: %w", err)
	}
	if revision < 1 {
		return p.Snapshot{}, errors.New("invalid stored voice preference revision")
	}
	if err := value.Validate(); err != nil {
		return p.Snapshot{}, fmt.Errorf("invalid stored voice preferences: %w", err)
	}
	return p.Snapshot{Revision: revision, Settings: value}, nil
}
