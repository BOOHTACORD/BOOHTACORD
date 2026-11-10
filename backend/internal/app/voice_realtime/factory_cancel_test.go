package voicerealtime

import (
	"context"
	"net/http"
	"testing"
	"time"

	auth "voice-platform/backend/internal/identity/authenticate_session"
	coordinator "voice-platform/backend/internal/voice/coordinate_roster"
	roster "voice-platform/backend/internal/voice/list_connected_participants"
	prepared "voice-platform/backend/internal/voice/prepare_roster_delivery"
)

func TestCloseCancelsInFlightGuard(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	c, err := coordinator.New(coordinator.Config{Workers: 1, MaxAccounts: 1, MaxSubscribers: 1, MaxSnapshotBytes: 4096, PollInterval: time.Hour, ReadTimeout: time.Second}, &lister{}, nil)
	if err != nil {
		t.Fatal(err)
	}
	go c.Run(ctx)
	pool, err := prepared.New(1, time.Second)
	if err != nil {
		t.Fatal(err)
	}
	entered, stopped := make(chan struct{}), make(chan struct{})
	guard := guardFunc(func(ctx context.Context, _ string, _ auth.Principal, _ roster.Result) error {
		close(entered)
		<-ctx.Done()
		close(stopped)
		return ctx.Err()
	})
	stream, err := New(c, pool, guard).Open(ctx, auth.Principal{AccountID: account}, &http.Cookie{Value: "opaque"})
	if err != nil {
		t.Fatal(err)
	}
	select {
	case <-entered:
	case <-time.After(time.Second):
		t.Fatal("guard did not start")
	}
	stream.Close()
	select {
	case <-stopped:
	case <-time.After(time.Second):
		t.Fatal("guard was not canceled")
	}
	select {
	case _, ok := <-stream.Events():
		if ok {
			t.Fatal("delivery after close")
		}
	case <-time.After(time.Second):
		t.Fatal("stream did not terminate")
	}
}
