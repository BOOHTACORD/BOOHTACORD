package preferences

import (
	"errors"
	"time"
)

type Mode string

const (
	ModeAll      Mode = "all"
	ModeMentions Mode = "mentions"
	ModeNone     Mode = "none"
)

const SchemaVersion = 1

var (
	ErrInvalid         = errors.New("invalid notification preferences")
	ErrConflict        = errors.New("notification preference revision conflict")
	ErrAlreadyImported = errors.New("notification preferences already imported")
)

type Preference struct {
	Mode        Mode       `json:"mode"`
	PausedUntil *time.Time `json:"paused_until"`
}

type Override struct {
	Kind string `json:"kind"`
	ID   string `json:"id"`
	Preference
}

type Settings struct {
	Version   int        `json:"version"`
	Revision  int64      `json:"revision"`
	Enabled   bool       `json:"enabled"`
	DM        Preference `json:"dm"`
	Text      Preference `json:"text"`
	Overrides []Override `json:"overrides"`
	Imported  bool       `json:"imported"`
}

type Input struct {
	AccountID        string
	ExpectedRevision int64
	Settings         Settings
	Import           bool
}

func Default() Settings {
	return Settings{Version: SchemaVersion, DM: Preference{Mode: ModeAll}, Text: Preference{Mode: ModeMentions}, Overrides: []Override{}}
}
