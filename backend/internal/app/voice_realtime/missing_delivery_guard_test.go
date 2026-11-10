package voicerealtime

import (
	"context"
	"errors"
	"testing"

	auth "voice-platform/backend/internal/identity/authenticate_session"
	guard "voice-platform/backend/internal/voice/authorize_roster_delivery"
	coordinator "voice-platform/backend/internal/voice/coordinate_roster"
	roster "voice-platform/backend/internal/voice/list_connected_participants"
)

type checkOnlyGuard struct{}

func (checkOnlyGuard) Check(context.Context, string, auth.Principal, roster.Result) error {
	return nil
}

func TestMissingAtomicDeliveryGuardFailsClosed(t *testing.T) {
	s := &stream{guard: checkOnlyGuard{}}
	called := false
	err := s.WithRoster(context.Background(), coordinator.State{}, func(context.Context) error {
		called = true
		return nil
	})
	if !errors.Is(err, guard.ErrUnavailable) || called {
		t.Fatalf("missing guard allowed delivery: called=%t err=%v", called, err)
	}
}
