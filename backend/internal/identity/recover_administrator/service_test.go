package recoveradministrator

import (
	"context"
	"errors"
	"testing"

	"voice-platform/backend/internal/identity/password"
)

func TestRecoverValidatesAndHashesReplacementPassword(t *testing.T) {
	accounts := &fakeAccounts{}
	err := New(accounts).Recover(context.Background(), Input{Login: "Owner", Password: "new correct horse battery staple"})
	if err != nil {
		t.Fatalf("Recover() error = %v", err)
	}
	if accounts.login != "owner" {
		t.Fatalf("login = %q", accounts.login)
	}
	if valid, err := password.Verify(context.Background(), "new correct horse battery staple", accounts.passwordHash); err != nil || !valid {
		t.Fatalf("stored password valid = %v, error = %v", valid, err)
	}
}

func TestRecoverDoesNotProceedWhenActiveAdminExistsOrTargetMissing(t *testing.T) {
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

func (accounts *fakeAccounts) RecoverLast(_ context.Context, login, passwordHash string) error {
	accounts.login = login
	accounts.passwordHash = passwordHash
	return accounts.err
}
