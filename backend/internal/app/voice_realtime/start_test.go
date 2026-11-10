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

func TestProcessInvalidatesAndStopsSharedStreams(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	reader := &lister{}
	notifier := watch.NewNotifier()
	guard := guardFunc(func(context.Context, string, auth.Principal, roster.Result) error { return nil })
	config := coordinator.Config{Workers: 1, MaxAccounts: 1, MaxSubscribers: 1, MaxSnapshotBytes: 4096, PollInterval: time.Hour, ReadTimeout: time.Second}
	factory, stop, err := Start(ctx, config, reader, guard, notifier)
	if err != nil {
		t.Fatal(err)
	}
	stream, err := factory.Open(ctx, auth.Principal{AccountID: account}, &http.Cookie{Value: "opaque"})
	if err != nil {
		t.Fatal(err)
	}
	defer stream.Close()
	select {
	case <-stream.Events():
	case <-time.After(time.Second):
		t.Fatal("initial roster missing")
	}
	before := reader.calls.Load()
	notifier.Notify()
	deadline := time.Now().Add(time.Second)
	for reader.calls.Load() == before && time.Now().Before(deadline) {
		time.Sleep(time.Millisecond)
	}
	if reader.calls.Load() == before {
		t.Fatal("notifier did not refresh coordinator")
	}
	shutdown, finish := context.WithTimeout(context.Background(), time.Second)
	defer finish()
	if err := stop(shutdown); err != nil {
		t.Fatal(err)
	}
	select {
	case _, open := <-stream.Events():
		if open {
			t.Fatal("stream remained open")
		}
	case <-time.After(time.Second):
		t.Fatal("shutdown left stream open")
	}
	if _, err := factory.Open(ctx, auth.Principal{AccountID: account}, &http.Cookie{Value: "opaque"}); err == nil {
		t.Fatal("stopped coordinator admitted a socket")
	}
}
