package bootstrapadministrator

import (
	"context"
	"errors"
	"fmt"

	"voice-platform/backend/internal/identity/password"
	"voice-platform/backend/internal/identity/registration"
)

var (
	ErrAlreadyInitialized  = errors.New("administrator bootstrap already initialized")
	ErrBootstrapIncomplete = errors.New("administrator bootstrap state is incomplete")
)

type Role string

const RoleAdministrator Role = "ADMINISTRATOR"

type Input struct {
	Login    string
	Password string
}

type Account struct {
	ID           string
	Login        string
	DisplayName  string
	Role         Role
	PasswordHash string
}

type Accounts interface {
	CreateInitial(context.Context, Account) error
}

type Service struct {
	accounts Accounts
	newID    func() (string, error)
}

func New(accounts Accounts) Service {
	return Service{accounts: accounts, newID: newAccountID}
}

func (service Service) Bootstrap(context context.Context, input Input) (Account, error) {
	validated, err := registration.Validate(registration.Input{Login: input.Login, DisplayName: input.Login, Password: input.Password})
	if err != nil {
		return Account{}, err
	}
	passwordHash, err := password.Hash(context, validated.Password)
	if err != nil {
		return Account{}, fmt.Errorf("hash bootstrap password: %w", err)
	}
	id, err := service.newID()
	if err != nil {
		return Account{}, fmt.Errorf("create administrator identifier: %w", err)
	}
	account := Account{ID: id, Login: validated.Login, DisplayName: validated.DisplayName, Role: RoleAdministrator, PasswordHash: passwordHash}
	if err := service.accounts.CreateInitial(context, account); err != nil {
		if errors.Is(err, ErrAlreadyInitialized) {
			return Account{}, ErrAlreadyInitialized
		}
		if errors.Is(err, ErrBootstrapIncomplete) {
			return Account{}, ErrBootstrapIncomplete
		}
		return Account{}, fmt.Errorf("create initial administrator: %w", err)
	}
	return account, nil
}
