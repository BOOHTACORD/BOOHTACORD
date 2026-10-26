package changeownpassword

import (
	"context"
	"crypto/sha256"
	"errors"
	"testing"

	"voice-platform/backend/internal/identity/password"
)

func TestChangeVerifiesCurrentPasswordAndKeepsSessionDigest(t *testing.T) {
	oldHash, err := password.Hash(context.Background(), "old secure password")
	if err != nil {
		t.Fatal("could not create test hash")
	}
	store := &fakeStore{passwordHash: oldHash}
	input := Input{AccountID: "account-1", CurrentPassword: "old secure password", NewPassword: "new secure password", CurrentSessionDigest: [sha256.Size]byte{0: 7}}
	if err := New(store).Change(context.Background(), input); err != nil {
		t.Fatalf("Change() error = %v", err)
	}
	if valid, err := password.Verify(context.Background(), input.NewPassword, store.newPasswordHash); err != nil || !valid {
		t.Fatalf("new password hash valid = %v, error = %v", valid, err)
	}
	if store.accountID != input.AccountID || store.currentHash != oldHash || store.currentSessionDigest != input.CurrentSessionDigest {
		t.Fatalf("change arguments = %#v", store)
	}
}

func TestChangeRejectsWrongCurrentPasswordBeforeUpdate(t *testing.T) {
	hash, err := password.Hash(context.Background(), "old secure password")
	if err != nil {
		t.Fatal("could not create test hash")
	}
	store := &fakeStore{passwordHash: hash}
	input := Input{AccountID: "account-1", CurrentPassword: "wrong secure password", NewPassword: "new secure password", CurrentSessionDigest: [sha256.Size]byte{0: 7}}
	if err := New(store).Change(context.Background(), input); !errors.Is(err, ErrCurrentPasswordInvalid) || store.changed {
		t.Fatalf("Change() error = %v, changed = %v", err, store.changed)
	}
}

func TestChangeRejectsInvalidNewPasswordAndMissingSessionDigest(t *testing.T) {
	for _, input := range []Input{
		{AccountID: "account-1", CurrentPassword: "old secure password", NewPassword: "short", CurrentSessionDigest: [sha256.Size]byte{0: 7}},
		{AccountID: "account-1", CurrentPassword: "old secure password", NewPassword: "new secure password"},
	} {
		store := &fakeStore{}
		if err := New(store).Change(context.Background(), input); !errors.Is(err, ErrInvalidInput) || store.found || store.changed {
			t.Fatalf("Change() error = %v, store = %#v", err, store)
		}
	}
}

type fakeStore struct {
	accountID            string
	passwordHash         string
	currentHash          string
	newPasswordHash      string
	currentSessionDigest [sha256.Size]byte
	found                bool
	changed              bool
	err                  error
}

func (store *fakeStore) FindPasswordHash(_ context.Context, accountID string) (string, error) {
	store.accountID = accountID
	store.found = true
	return store.passwordHash, nil
}

func (store *fakeStore) ChangePassword(_ context.Context, accountID, currentHash, newHash string, digest [sha256.Size]byte) error {
	store.accountID = accountID
	store.currentHash = currentHash
	store.newPasswordHash = newHash
	store.currentSessionDigest = digest
	store.changed = true
	return store.err
}
