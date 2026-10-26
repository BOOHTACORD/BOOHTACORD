package preferencespostgres

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"

	"github.com/jackc/pgx/v5"
	preferences "voice-platform/backend/internal/notifications/preferences"
)

type Row = pgx.Row

type Database interface {
	QueryRow(context.Context, string, ...any) Row
}

type Repository struct{ database Database }

func New(database Database) Repository { return Repository{database: database} }

func (repository Repository) Read(context context.Context, accountID string) (preferences.Settings, error) {
	var document []byte
	err := repository.database.QueryRow(context, readPreferences, accountID).Scan(&document)
	if errors.Is(err, pgx.ErrNoRows) {
		return preferences.Default(), nil
	}
	if err != nil {
		return preferences.Settings{}, fmt.Errorf("read notification preferences: %w", err)
	}
	var settings preferences.Settings
	if err := json.Unmarshal(document, &settings); err != nil {
		return preferences.Settings{}, fmt.Errorf("decode notification preferences: %w", err)
	}
	settings.Version = preferences.SchemaVersion
	if settings.Overrides == nil {
		settings.Overrides = []preferences.Override{}
	}
	return settings, nil
}

func (repository Repository) Save(context context.Context, input preferences.Input) (preferences.Settings, error) {
	if input.Settings.Overrides == nil {
		input.Settings.Overrides = []preferences.Override{}
	}
	document, err := json.Marshal(input.Settings)
	if err != nil {
		return preferences.Settings{}, fmt.Errorf("encode notification preferences: %w", err)
	}
	var accountID string
	var version int
	var revision int64
	var imported bool
	var settings []byte
	err = repository.database.QueryRow(context, savePreferences, input.AccountID, document, input.ExpectedRevision, input.Import).Scan(&accountID, &version, &revision, &imported, &settings)
	if errors.Is(err, pgx.ErrNoRows) {
		return preferences.Settings{}, repository.classifyConflict(context, input)
	}
	if err != nil {
		return preferences.Settings{}, fmt.Errorf("save notification preferences: %w", err)
	}
	var decoded preferences.Settings
	if err := json.Unmarshal(settings, &decoded); err != nil {
		return preferences.Settings{}, fmt.Errorf("decode notification preferences: %w", err)
	}
	decoded.Version = version
	decoded.Revision = revision
	decoded.Imported = imported
	return decoded, nil
}

func (repository Repository) classifyConflict(context context.Context, input preferences.Input) error {
	if !input.Import {
		return preferences.ErrConflict
	}
	var imported bool
	err := repository.database.QueryRow(context, currentImported, input.AccountID).Scan(&imported)
	if errors.Is(err, pgx.ErrNoRows) || err != nil {
		return preferences.ErrConflict
	}
	if imported {
		return preferences.ErrAlreadyImported
	}
	return preferences.ErrConflict
}
