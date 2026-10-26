package registeruser

import (
	"context"
	"crypto/rand"
	"errors"
	"fmt"
	"io"

	"voice-platform/backend/internal/identity/password"
	"voice-platform/backend/internal/identity/registration"
)

var (
	ErrNoRepository            = errors.New("account repository is required")
	ErrLoginTaken              = errors.New("login already taken")
	ErrRegistrationUnavailable = errors.New("registration is unavailable until administrator bootstrap")
)

type Role string

const RoleMember Role = "MEMBER"

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
	Create(context.Context, Account) error
}

type Service struct {
	accounts Accounts
	newID    func() (string, error)
}

func New(accounts Accounts) Service {
	return Service{accounts: accounts, newID: newAccountID}
}

func (service Service) Register(context context.Context, input Input) (Account, error) {
	if service.accounts == nil {
		return Account{}, ErrNoRepository
	}

	validated, err := registration.Validate(registration.Input{
		Login:       input.Login,
		DisplayName: input.Login,
		Password:    input.Password,
	})
	if err != nil {
		return Account{}, err
	}
	hash, err := password.Hash(context, validated.Password)
	if err != nil {
		return Account{}, fmt.Errorf("hash password: %w", err)
	}
	id, err := service.newID()
	if err != nil {
		return Account{}, fmt.Errorf("create account identifier: %w", err)
	}

	account := Account{
		ID:           id,
		Login:        validated.Login,
		DisplayName:  validated.DisplayName,
		Role:         RoleMember,
		PasswordHash: hash,
	}
	if err := service.accounts.Create(context, account); err != nil {
		return Account{}, fmt.Errorf("persist account: %w", err)
	}
	return account, nil
}

func newAccountID() (string, error) {
	bytes := make([]byte, 16)
	if _, err := io.ReadFull(rand.Reader, bytes); err != nil {
		return "", err
	}
	bytes[6] = (bytes[6] & 0x0f) | 0x40
	bytes[8] = (bytes[8] & 0x3f) | 0x80
	return fmt.Sprintf("%x-%x-%x-%x-%x", bytes[0:4], bytes[4:6], bytes[6:8], bytes[8:10], bytes[10:16]), nil
}
