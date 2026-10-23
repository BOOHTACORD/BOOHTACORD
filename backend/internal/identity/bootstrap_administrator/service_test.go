package bootstrapadministrator

import (
	"context"
	"errors"
	"testing"

	"voice-platform/backend/internal/identity/password"
)

func TestBootstrapCreatesAdministratorWithoutReusingRegistrationRole(t *testing.T) {
	accounts := &fakeAccounts{}
	service := New(accounts)
	service.newID = func() (string, error) { return "77b14148-7723-4c14-8e69-20a5d9b77972", nil }

	account, err := service.Bootstrap(context.Background(), Input{Login: "Owner", Password: "correct horse battery staple"})
	if err != nil {
		t.Fatalf("Bootstrap() error = %v", err)
	}
	if account.ID != "77b14148-7723-4c14-8e69-20a5d9b77972" || account.Login != "owner" || account.Role != RoleAdministrator {
		t.Fatalf("account = %#v", account)
	}
	if valid, err := password.Verify(context.Background(), "correct horse battery staple", accounts.account.PasswordHash); err != nil || !valid {
		t.Fatalf("stored password valid = %v, error = %v", valid, err)
	}
}

func TestBootstrapReportsExistingInitializationWithoutChangingAccount(t *testing.T) {
	accounts := &fakeAccounts{err: ErrAlreadyInitialized}
	service := New(accounts)
	_, err := service.Bootstrap(context.Background(), Input{Login: "owner", Password: "correct horse battery staple"})
	if !errors.Is(err, ErrAlreadyInitialized) {
		t.Fatalf("Bootstrap() error = %v", err)
	}
}

func TestBootstrapReportsIncompleteStateWithoutCreatingAnotherAccount(t *testing.T) {
	accounts := &fakeAccounts{err: ErrBootstrapIncomplete}
	service := New(accounts)
	_, err := service.Bootstrap(context.Background(), Input{Login: "owner", Password: "correct horse battery staple"})
	if !errors.Is(err, ErrBootstrapIncomplete) {
		t.Fatalf("Bootstrap() error = %v", err)
	}
}

type fakeAccounts struct {
	account Account
	err     error
}

func (accounts *fakeAccounts) CreateInitial(_ context.Context, account Account) error {
	accounts.account = account
	return accounts.err
}
