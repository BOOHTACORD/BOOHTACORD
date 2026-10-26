package preferences

import (
	"fmt"
	"time"

	"github.com/google/uuid"
)

const maxOverrides = 100

func validateMode(mode Mode) error {
	switch mode {
	case ModeAll, ModeMentions, ModeNone:
		return nil
	default:
		return fmt.Errorf("%w: unknown mode %q", ErrInvalid, mode)
	}
}

func validatePause(pause *time.Time) error {
	if pause == nil {
		return nil
	}
	if pause.Year() < 1 || pause.Year() > 9999 {
		return fmt.Errorf("%w: pause outside supported range", ErrInvalid)
	}
	// A stored pause must be a UTC instant; the zone offset is the real check.
	if _, offset := pause.Zone(); offset != 0 {
		return fmt.Errorf("%w: pause must be UTC", ErrInvalid)
	}
	return nil
}

func uuidCheck(accountID string) (string, error) {
	if id, err := uuid.Parse(accountID); err != nil || id == uuid.Nil {
		return "", fmt.Errorf("%w: actor account is not a UUID", ErrInvalid)
	}
	return accountID, nil
}

func validatePreference(preference Preference) error {
	if err := validateMode(preference.Mode); err != nil {
		return err
	}
	return validatePause(preference.PausedUntil)
}

func validateOverride(override Override) error {
	if override.Kind != "CHANNEL" && override.Kind != "DIRECT_MESSAGE" {
		return fmt.Errorf("%w: unknown override kind %q", ErrInvalid, override.Kind)
	}
	if id, err := uuid.Parse(override.ID); err != nil || id == uuid.Nil {
		return fmt.Errorf("%w: invalid override id", ErrInvalid)
	}
	return validatePreference(override.Preference)
}

func Validate(input Input) error {
	if _, err := uuidCheck(input.AccountID); err != nil {
		return fmt.Errorf("%w: actor account is not a UUID", ErrInvalid)
	}
	if input.ExpectedRevision < 0 {
		return fmt.Errorf("%w: expected revision must be >= 0", ErrInvalid)
	}
	settings := input.Settings
	if settings.Revision < 0 {
		return fmt.Errorf("%w: settings revision must be >= 0", ErrInvalid)
	}
	if settings.Version != SchemaVersion {
		return fmt.Errorf("%w: unsupported version %d", ErrInvalid, settings.Version)
	}
	if err := validatePreference(settings.DM); err != nil {
		return err
	}
	if err := validatePreference(settings.Text); err != nil {
		return err
	}
	seen := make(map[string]struct{}, len(settings.Overrides))
	if len(settings.Overrides) > maxOverrides {
		return fmt.Errorf("%w: too many overrides", ErrInvalid)
	}
	for _, override := range settings.Overrides {
		if err := validateOverride(override); err != nil {
			return err
		}
		// Canonicalize the UUID so case or hyphen variants of the same
		// conversation cannot alias past the duplicate check, while a UUID
		// shared across two different kinds remains legal.
		canonical := uuid.MustParse(override.ID).String()
		key := override.Kind + "\x00" + canonical
		if _, exists := seen[key]; exists {
			return fmt.Errorf("%w: duplicate override %s", ErrInvalid, key)
		}
		seen[key] = struct{}{}
	}
	return nil
}
