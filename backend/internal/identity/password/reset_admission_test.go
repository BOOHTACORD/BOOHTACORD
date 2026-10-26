package password_test

import (
	"context"
	"crypto/sha256"
	"errors"
	"testing"

	reset "voice-platform/backend/internal/identity/complete_password_reset"
	"voice-platform/backend/internal/identity/password"
	"voice-platform/backend/internal/identity/session"
)

func TestCancelledResetDoesNotDeriveOrMutate(t *testing.T) {
	issued, err := session.Issue()
	if err != nil {
		t.Fatal("cannot prepare synthetic reset")
	}
	ctx, cancel := context.WithCancel(context.Background())
	cancel()
	count := password.CountDerivationsForTest(t)
	store := &cancelledResetStore{}
	err = reset.New(store).Complete(ctx, reset.Input{Token: issued.Token, Password: "synthetic replacement password"})
	if !errors.Is(err, context.Canceled) || count() != 0 || store.calls != 0 {
		t.Fatalf("cancelled reset: cancelled=%v KDF=%d mutations=%d; want true/0/0", errors.Is(err, context.Canceled), count(), store.calls)
	}
}

type cancelledResetStore struct{ calls int }

func (store *cancelledResetStore) Consume(ctx context.Context, _ [sha256.Size]byte, _ string) error {
	store.calls++
	return ctx.Err()
}

func (store *cancelledResetStore) Preflight(ctx context.Context, _ [sha256.Size]byte) error {
	store.calls++
	return ctx.Err()
}
