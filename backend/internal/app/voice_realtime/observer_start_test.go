package voicerealtime

import (
	"context"
	"net/http"
	"testing"
	"time"
	auth "voice-platform/backend/internal/identity/authenticate_session"
	coordinator "voice-platform/backend/internal/voice/coordinate_roster"
	roster "voice-platform/backend/internal/voice/list_connected_participants"
	watch "voice-platform/backend/internal/voice/watch_connected_participants"
)

func TestStartWiresOneObserverToRefreshAndSubscriber(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	observer := &rosterObserver{}
	checker := guardFunc(func(context.Context, string, auth.Principal, roster.Result) error { return nil })
	config := coordinator.Config{Workers: 1, MaxAccounts: 1, MaxSubscribers: 1, MaxSnapshotBytes: 4096, PollInterval: time.Hour, ReadTimeout: time.Second}
	factory, stop, err := Start(ctx, config, &lister{}, checker, watch.NewNotifier(), observer)
	if err != nil {
		t.Fatal(err)
	}
	defer stop(context.Background())
	stream, err := factory.Open(ctx, auth.Principal{AccountID: account}, &http.Cookie{Value: "opaque"})
	if err != nil {
		t.Fatal(err)
	}
	defer stream.Close()
	select {
	case <-stream.Events():
	case <-time.After(time.Second):
		t.Fatal("missing delivery")
	}
	deadline := time.Now().Add(time.Second)
	for observer.refresh.Load() == 0 && time.Now().Before(deadline) {
		time.Sleep(time.Millisecond)
	}
	if observer.opened.Load() != 1 || observer.refresh.Load() != 1 {
		t.Fatal("observer not wired to both owners")
	}
}
