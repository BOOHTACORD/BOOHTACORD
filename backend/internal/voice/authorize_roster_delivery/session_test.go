package authorizerosterdelivery

import (
	"context"
	"errors"
	"testing"

	auth "voice-platform/backend/internal/identity/authenticate_session"
	roster "voice-platform/backend/internal/voice/list_connected_participants"
)

func TestRevocationDuringVisibilityReadStopsDelivery(t *testing.T) {
	principal, snapshot, visible := fixture()
	calls := 0
	guard := New(authFunc(func(context.Context, string) (auth.Principal, error) {
		calls++
		if calls == 2 {
			return auth.Principal{}, auth.ErrUnauthenticated
		}
		return principal, nil
	}), repoFunc(func(context.Context, string) ([]roster.Channel, error) { return visible, nil }))
	if err := guard.Check(context.Background(), "opaque", principal, snapshot); !errors.Is(err, ErrSession) {
		t.Fatalf("revocation: %v", err)
	}
}

func TestDatabaseFailuresRemainUnavailableWithoutDetails(t *testing.T) {
	principal, snapshot, _ := fixture()
	guard := New(authFunc(func(context.Context, string) (auth.Principal, error) { return principal, nil }), repoFunc(func(context.Context, string) ([]roster.Channel, error) {
		return nil, errors.New("private database detail")
	}))
	if err := guard.Check(context.Background(), "opaque", principal, snapshot); !errors.Is(err, ErrUnavailable) || err.Error() != ErrUnavailable.Error() {
		t.Fatalf("failure classification: %v", err)
	}
	guard = New(authFunc(func(context.Context, string) (auth.Principal, error) {
		return auth.Principal{}, errors.New("private session detail")
	}), repoFunc(func(context.Context, string) ([]roster.Channel, error) { t.Fatal("repository called"); return nil, nil }))
	if err := guard.Check(context.Background(), "opaque", principal, snapshot); !errors.Is(err, ErrUnavailable) {
		t.Fatalf("session store failure: %v", err)
	}
}

func TestWrongSessionAndRevocationAreRejected(t *testing.T) {
	principal, snapshot, visible := fixture()
	other := principal
	other.SessionDigest[0] ^= 1
	for _, current := range []auth.Principal{other, {AccountID: "other", SessionDigest: principal.SessionDigest}} {
		guard := New(authFunc(func(context.Context, string) (auth.Principal, error) { return current, nil }), repoFunc(func(context.Context, string) ([]roster.Channel, error) { return visible, nil }))
		if err := guard.Check(context.Background(), "opaque", principal, snapshot); !errors.Is(err, ErrSession) {
			t.Fatalf("wrong session: %v", err)
		}
	}
}

func TestCanceledSessionLookupDoesNotPretendSessionWasRevoked(t *testing.T) {
	principal, snapshot, _ := fixture()
	ctx, cancel := context.WithCancel(context.Background())
	cancel()
	guard := New(authFunc(func(context.Context, string) (auth.Principal, error) {
		return auth.Principal{}, auth.ErrUnauthenticated
	}), repoFunc(func(context.Context, string) ([]roster.Channel, error) { t.Fatal("repository called"); return nil, nil }))
	if err := guard.Check(ctx, "opaque", principal, snapshot); !errors.Is(err, ErrUnavailable) {
		t.Fatalf("canceled lookup: %v", err)
	}
}
