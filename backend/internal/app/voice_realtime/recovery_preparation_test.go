package voicerealtime

import (
	"context"
	"net/http"
	"sync/atomic"
	"testing"
	"time"

	auth "voice-platform/backend/internal/identity/authenticate_session"
	guard "voice-platform/backend/internal/voice/authorize_roster_delivery"
	coordinator "voice-platform/backend/internal/voice/coordinate_roster"
	roster "voice-platform/backend/internal/voice/list_connected_participants"
	prepared "voice-platform/backend/internal/voice/prepare_roster_delivery"
)

func TestUnchangedRosterRecoversAfterPreparationGuardUnavailable(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	reader := &lister{}
	c, err := coordinator.New(coordinator.Config{Workers: 1, MaxAccounts: 1, MaxSubscribers: 1, MaxSnapshotBytes: 4096, PollInterval: 30 * time.Millisecond, ReadTimeout: time.Second}, reader, nil)
	if err != nil {
		t.Fatal(err)
	}
	go c.Run(ctx)
	pool, err := prepared.New(1, time.Second)
	if err != nil {
		t.Fatal(err)
	}
	var checks atomic.Int32
	checker := guardFunc(func(context.Context, string, auth.Principal, roster.Result) error {
		if checks.Add(1) == 1 {
			return guard.ErrUnavailable
		}
		return nil
	})
	stream, err := New(c, pool, checker).Open(ctx, auth.Principal{AccountID: account}, &http.Cookie{Value: "opaque"})
	if err != nil {
		t.Fatal(err)
	}
	defer stream.Close()
	select {
	case got := <-stream.Events():
		if !got.Unavailable {
			t.Fatalf("first event: %+v", got)
		}
	case <-time.After(time.Second):
		t.Fatal("unavailable not delivered")
	}
	select {
	case got := <-stream.Events():
		if got.Unavailable || len(got.State.Roster.Channels) != 1 {
			t.Fatalf("recovery: %+v", got)
		}
	case <-time.After(500 * time.Millisecond):
		t.Fatalf("unchanged roster did not recover; reads=%d checks=%d", reader.calls.Load(), checks.Load())
	}
}
