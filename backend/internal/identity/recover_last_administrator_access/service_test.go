package recoverlastadministratoraccess

import (
	"context"
	"errors"
	"testing"

	"voice-platform/backend/internal/identity/password"
)

func TestRecoverNormalizesLoginAndHashesReplacementPassword(t *testing.T) {
	accounts := &fakeAccounts{}
	if err := New(accounts).Recover(context.Background(), Input{Login: "Owner", Password: "new correct horse battery staple"}); err != nil {
		t.Fatalf("Recover() error = %v", err)
	}
	if accounts.login != "owner" {
		t.Fatalf("login = %q", accounts.login)
	}
	valid, err := password.Verify(context.Background(), "new correct horse battery staple", accounts.passwordHash)
	if err != nil || !valid {
		t.Fatalf("replacement password valid = %v, error = %v", valid, err)
	}
}

func TestRecoverReturnsUnavailableForUnsafeTarget(t *testing.T) {
	accounts := &fakeAccounts{err: ErrRecoveryUnavailable}
	err := New(accounts).Recover(context.Background(), Input{Login: "owner", Password: "new correct horse battery staple"})
	if !errors.Is(err, ErrRecoveryUnavailable) {
		t.Fatalf("Recover() error = %v", err)
	}
}

type fakeAccounts struct {
	login        string
	passwordHash string
	err          error
}

func (accounts *fakeAccounts) RecoverSoleActiveAdministrator(_ context.Context, login, passwordHash string) error {
	accounts.login = login
	accounts.passwordHash = passwordHash
	return accounts.err
}
