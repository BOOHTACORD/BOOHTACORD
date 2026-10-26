package recoveradministrator

import (
	"context"
	"errors"
	"fmt"

	"voice-platform/backend/internal/identity/password"
	"voice-platform/backend/internal/identity/registration"
)

var ErrRecoveryUnavailable = errors.New("administrator recovery unavailable")

type Input struct {
	Login    string
	Password string
}

type Accounts interface {
	RecoverLast(context.Context, string, string) error
}

type Service struct {
	accounts Accounts
}

func New(accounts Accounts) Service {
	return Service{accounts: accounts}
}

func (service Service) Recover(context context.Context, input Input) error {
	login, err := registration.NormalizeLogin(input.Login)
	if err != nil {
		return ErrRecoveryUnavailable
	}
	if err := registration.ValidatePassword(input.Password); err != nil {
		return ErrRecoveryUnavailable
	}
	passwordHash, err := password.Hash(context, input.Password)
	if err != nil {
		return fmt.Errorf("hash recovery password: %w", err)
	}
	if err := service.accounts.RecoverLast(context, login, passwordHash); err != nil {
		if errors.Is(err, ErrRecoveryUnavailable) {
			return ErrRecoveryUnavailable
		}
		return fmt.Errorf("recover administrator: %w", err)
	}
	return nil
}
