package loginuser

import (
	"context"
	"errors"
	"testing"
	"time"

	"voice-platform/backend/internal/identity/password"
	"voice-platform/backend/internal/identity/session"
)

func TestLoginNormalizesLoginAndCreatesServerSideSession(t *testing.T) {
	hash, err := password.Hash(context.Background(), "correct horse battery staple")
	if err != nil {
		t.Fatalf("Hash() error = %v", err)
	}
	accounts := &fakeAccounts{account: Account{ID: "account-1", Login: "egor", PasswordHash: hash}}
	sessions := &fakeSessions{}
	service := New(accounts, sessions)

	result, err := service.Login(context.Background(), Input{
		Login:    "EGOR",
		Password: "correct horse battery staple",
	})
	if err != nil {
		t.Fatalf("Login() error = %v", err)
	}
	if accounts.requestedLogin != "egor" {
		t.Fatalf("repository login = %q, want normalized value", accounts.requestedLogin)
	}
	if sessions.accountID != "account-1" || !session.Verify(result.Token, sessions.digest) {
		t.Fatal("Login() did not create a verifiable server-side session")
	}
	if result.ExpiresAt.Before(time.Now().Add(session.AbsoluteLifetime-time.Minute)) || result.ExpiresAt.After(time.Now().Add(session.AbsoluteLifetime+time.Minute)) || !sessions.expiresAt.Equal(result.ExpiresAt) {
		t.Fatalf("session expiry = %s, stored expiry = %s", result.ExpiresAt, sessions.expiresAt)
	}
}

func TestLoginRejectsWrongOrUnknownCredentialsWithoutSession(t *testing.T) {
	hash, err := password.Hash(context.Background(), "correct horse battery staple")
	if err != nil {
		t.Fatalf("Hash() error = %v", err)
	}

	for _, test := range []struct {
		name     string
		accounts *fakeAccounts
		password string
	}{
		{"wrong password", &fakeAccounts{account: Account{ID: "account-1", PasswordHash: hash}}, "not the password"},
		{"unknown login", &fakeAccounts{err: ErrAccountNotFound}, "correct horse battery staple"},
	} {
		t.Run(test.name, func(t *testing.T) {
			sessions := &fakeSessions{}
			service := New(test.accounts, sessions)
			_, err := service.Login(context.Background(), Input{Login: "egor", Password: test.password})
			if !errors.Is(err, ErrInvalidCredentials) || sessions.accountID != "" {
				t.Fatalf("Login() error = %v, session = %#v", err, sessions)
			}
		})
	}
}

func TestLoginRejectsBlockedAccount(t *testing.T) {
	hash, err := password.Hash(context.Background(), "correct horse battery staple")
	if err != nil {
		t.Fatal(err)
	}
	for _, test := range []struct {
		name, inputPassword string
		want                error
	}{
		{"wrong password", "not correct", ErrInvalidCredentials},
		{"correct password", "correct horse battery staple", ErrBlocked},
	} {
		t.Run(test.name, func(t *testing.T) {
			service := New(&fakeAccounts{account: Account{ID: "account-1", Blocked: true, PasswordHash: hash}}, &fakeSessions{})
			_, got := service.Login(context.Background(), Input{Login: "egor", Password: test.inputPassword})
			if !errors.Is(got, test.want) {
				t.Fatalf("Login() error = %v, want %v", got, test.want)
			}
		})
	}
}

type fakeAccounts struct {
	account        Account
	err            error
	requestedLogin string
}

func (accounts *fakeAccounts) FindByLogin(_ context.Context, login string) (Account, error) {
	accounts.requestedLogin = login
	return accounts.account, accounts.err
}

type fakeSessions struct {
	accountID string
	digest    [32]byte
	expiresAt time.Time
}

func (sessions *fakeSessions) Create(_ context.Context, accountID string, digest [32]byte, expiresAt time.Time) error {
	sessions.accountID = accountID
	sessions.digest = digest
	sessions.expiresAt = expiresAt
	return nil
}
