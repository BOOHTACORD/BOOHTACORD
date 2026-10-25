package preferences

import (
	"context"
	"fmt"
	"github.com/google/uuid"
)

type Store interface {
	Read(context.Context, string) (Settings, error)
	Save(context.Context, Input) (Settings, error)
}

type Service struct{ store Store }

func New(store Store) Service { return Service{store: store} }

func (service Service) Read(context context.Context, accountID string) (Settings, error) {
	if _, err := uuidCheck(accountID); err != nil {
		return Settings{}, err
	}
	settings, err := service.store.Read(context, accountID)
	if err != nil {
		return Settings{}, fmt.Errorf("read notification preferences: %w", err)
	}
	return settings, nil
}

func (service Service) Save(context context.Context, input Input) (Settings, error) {
	if err := Validate(input); err != nil {
		return Settings{}, err
	}
	input.AccountID = uuid.MustParse(input.AccountID).String()
	if input.Settings.Overrides != nil {
		overrides := make([]Override, len(input.Settings.Overrides))
		copy(overrides, input.Settings.Overrides)
		input.Settings.Overrides = overrides
	}
	for i := range input.Settings.Overrides {
		input.Settings.Overrides[i].ID = uuid.MustParse(input.Settings.Overrides[i].ID).String()
	}
	settings, err := service.store.Save(context, input)
	if err != nil {
		return Settings{}, fmt.Errorf("save notification preferences: %w", err)
	}
	return settings, nil
}
