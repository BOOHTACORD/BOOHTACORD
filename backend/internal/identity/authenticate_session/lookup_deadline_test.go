package authenticatesession

import (
	"context"
	"crypto/sha256"
	"errors"
	"testing"
	"time"
	"voice-platform/backend/internal/identity/session"
)

type deadlineStoreFunc func(context.Context, [sha256.Size]byte) (Principal, error)

func (f deadlineStoreFunc) FindActive(ctx context.Context, d [sha256.Size]byte) (Principal, error) {
	return f(ctx, d)
}
func TestAuthenticateBoundsStoreLookupAndReleasesIt(t *testing.T) {
	issued, err := session.Issue()
	if err != nil {
		t.Fatal(err)
	}
	var lookup context.Context
	store := deadlineStoreFunc(func(ctx context.Context, _ [sha256.Size]byte) (Principal, error) {
		lookup = ctx
		deadline, ok := ctx.Deadline()
		if !ok {
			t.Error("initial session lookup has no server deadline")
		} else if left := time.Until(deadline); left <= 0 || left > 5*time.Second {
			t.Error("lookup exceeds existing five-second roster budget")
		}
		return Principal{AccountID: "test-actor", Role: "MEMBER"}, nil
	})
	if _, err := New(store).Authenticate(context.Background(), issued.Token); err != nil {
		t.Fatal(err)
	}
	if lookup.Err() != context.Canceled {
		t.Error("completed lookup context was not released")
	}
}
func TestAuthenticateHonorsEarlierCallerDeadline(t *testing.T) {
	issued, err := session.Issue()
	if err != nil {
		t.Fatal(err)
	}
	ctx, cancel := context.WithTimeout(context.Background(), 20*time.Millisecond)
	defer cancel()
	store := deadlineStoreFunc(func(ctx context.Context, _ [sha256.Size]byte) (Principal, error) {
		<-ctx.Done()
		return Principal{}, ctx.Err()
	})
	_, err = New(store).Authenticate(ctx, issued.Token)
	if !errors.Is(err, context.DeadlineExceeded) {
		t.Fatal("caller deadline not preserved")
	}
}
