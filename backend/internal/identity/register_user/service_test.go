package registeruser

import (
	"context"
	"errors"
	"testing"

	"voice-platform/backend/internal/identity/password"
)

func TestRegisterCreatesNormalizedMemberWithPasswordHash(t *testing.T) {
	repository := &fakeRepository{}
	service := Service{
		accounts: repository,
		newID:    func() (string, error) { return "account-1", nil },
	}

	account, err := service.Register(context.Background(), Input{
		Login:    "Egor_Player",
		Password: "correct horse battery staple",
	})
	if err != nil {
		t.Fatalf("Register() error = %v", err)
	}
	if account.ID != "account-1" || account.Login != "egor_player" || account.DisplayName != "Egor_Player" || account.Role != RoleMember {
		t.Fatalf("account = %#v", account)
	}
	if account.PasswordHash == "correct horse battery staple" {
		t.Fatal("Register() persisted a plaintext password")
	}
	if matches, err := password.Verify(context.Background(), "correct horse battery staple", account.PasswordHash); err != nil || !matches {
		t.Fatalf("stored password hash did not verify: %v, %v", matches, err)
	}
	if repository.account != account {
		t.Fatal("Register() did not persist the created account")
	}
}

func TestRegisterDoesNotHideRepositoryConflict(t *testing.T) {
	want := errors.New("login already exists")
	service := Service{
		accounts: &fakeRepository{err: want},
		newID:    func() (string, error) { return "account-1", nil },
	}

	_, err := service.Register(context.Background(), Input{
		Login:    "egor",
		Password: "correct horse battery staple",
	})
	if !errors.Is(err, want) {
		t.Fatalf("Register() error = %v, want repository conflict", err)
	}
}

func TestRegisterDoesNotHideBootstrapRegistrationGate(t *testing.T) {
	service := Service{
		accounts: &fakeRepository{err: ErrRegistrationUnavailable},
		newID:    func() (string, error) { return "account-1", nil },
	}

	_, err := service.Register(context.Background(), Input{
		Login:    "member",
		Password: "correct horse battery staple",
	})
	if !errors.Is(err, ErrRegistrationUnavailable) {
		t.Fatalf("Register() error = %v", err)
	}
}

type fakeRepository struct {
	account Account
	err     error
}

func (repository *fakeRepository) Create(_ context.Context, account Account) error {
	if repository.err != nil {
		return repository.err
	}
	repository.account = account
	return nil
}
