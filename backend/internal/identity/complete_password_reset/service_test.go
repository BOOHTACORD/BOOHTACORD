package completepasswordreset

import (
	"context"
	"crypto/sha256"
	"errors"
	"testing"

	"voice-platform/backend/internal/identity/password"
	"voice-platform/backend/internal/identity/session"
)

func TestCompleteHashesNewPasswordAndConsumesReset(t *testing.T) {
	store := &fakeStore{}
	service := New(store)
	issued, err := session.Issue()
	if err != nil {
		t.Fatalf("Issue() error = %v", err)
	}

	err = service.Complete(context.Background(), Input{Token: issued.Token, Password: "new correct horse battery staple"})
	if err != nil {
		t.Fatalf("Complete() error = %v", err)
	}
	if !session.Verify(issued.Token, store.digest) {
		t.Fatal("store did not receive reset digest")
	}
	if valid, err := password.Verify(context.Background(), "new correct horse battery staple", store.passwordHash); err != nil || !valid {
		t.Fatalf("stored password hash valid = %v, error = %v", valid, err)
	}
}

func TestCompleteRejectsMalformedTokenOrPasswordBeforePersistence(t *testing.T) {
	for _, input := range []Input{
		{Token: "malformed", Password: "new correct horse battery staple"},
		{Token: "anything", Password: "short"},
	} {
		store := &fakeStore{}
		err := New(store).Complete(context.Background(), input)
		if !errors.Is(err, ErrInvalidOrExpired) || store.called {
			t.Fatalf("Complete(%#v) error = %v, called = %v", input, err, store.called)
		}
	}
}

func TestCompleteMapsMissingResetWithoutLeakingState(t *testing.T) {
	issued, err := session.Issue()
	if err != nil {
		t.Fatalf("Issue() error = %v", err)
	}
	service := New(&fakeStore{err: ErrResetNotFound})
	err = service.Complete(context.Background(), Input{Token: issued.Token, Password: "new correct horse battery staple"})
	if !errors.Is(err, ErrInvalidOrExpired) {
		t.Fatalf("Complete() error = %v", err)
	}
}

type fakeStore struct {
	digest       [sha256.Size]byte
	passwordHash string
	err          error
	called       bool
}

func (store *fakeStore) Consume(_ context.Context, digest [sha256.Size]byte, passwordHash string) error {
	store.digest = digest
	store.passwordHash = passwordHash
	store.called = true
	return store.err
}
