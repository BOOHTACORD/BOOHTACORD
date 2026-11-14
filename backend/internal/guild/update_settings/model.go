package guildsettings

import (
	"context"
	"errors"
)

var (
	ErrInvalid  = errors.New("invalid guild settings")
	ErrConflict = errors.New("guild settings revision conflict")
	ErrChannel  = errors.New("guild settings channel unavailable")
)

type Settings struct {
	Name              string  `json:"name"`
	Revision          int64   `json:"revision"`
	WelcomeChannelID  *string `json:"welcome_channel_id"`
	AFKChannelID      *string `json:"afk_channel_id"`
	AFKTimeoutSeconds int     `json:"afk_timeout_seconds"`
}
type Input struct {
	ActorID                              string
	ExpectedRevision                     int64
	SetName, SetWelcome, SetAFK          bool
	Name, WelcomeChannelID, AFKChannelID string
	AFKTimeoutSeconds                    int
}
type Result struct {
	Settings
	ChangedFields []string
}
type Store interface {
	Read(context.Context) (Settings, error)
	Update(context.Context, Input) (Result, error)
}
