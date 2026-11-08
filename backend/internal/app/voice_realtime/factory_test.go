package voicerealtime

import (
	"context"
	"net/http"
	"sync/atomic"
	"testing"
	"time"

	auth "voice-platform/backend/internal/identity/authenticate_session"
	coordinator "voice-platform/backend/internal/voice/coordinate_roster"
	roster "voice-platform/backend/internal/voice/list_connected_participants"
	prepared "voice-platform/backend/internal/voice/prepare_roster_delivery"
)

const account = "11111111-1111-4111-8111-111111111111"

type lister struct{ calls atomic.Int32 }

func (l *lister) List(_ context.Context, id string) (roster.Result, error) {
	l.calls.Add(1)
	return roster.Result{Channels: []roster.ChannelRoster{{ChannelID: id, Participants: []roster.Participant{}}}}, nil
}

type guardFunc func(context.Context, string, auth.Principal, roster.Result) error

func (g guardFunc) Check(ctx context.Context, token string, principal auth.Principal, result roster.Result) error {
	return g(ctx, token, principal, result)
}

func TestFactoryBindsAndStopsPerSocket(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	reader := &lister{}
	c, err := coordinator.New(coordinator.Config{Workers: 1, MaxAccounts: 1, MaxSubscribers: 1, MaxSnapshotBytes: 4096, PollInterval: time.Hour, ReadTimeout: time.Second}, reader, nil)
	if err != nil {
		t.Fatal(err)
	}
	go c.Run(ctx)
	pool, err := prepared.New(1, time.Second)
	if err != nil {
		t.Fatal(err)
	}
	var checks atomic.Int32
	guard := guardFunc(func(_ context.Context, token string, principal auth.Principal, result roster.Result) error {
		if token != "opaque" || principal.AccountID != account || len(result.Channels) != 1 || result.Channels[0].ChannelID != account {
			t.Error("incorrect recipient binding")
		}
		checks.Add(1)
		return nil
	})
	factory := New(c, pool, guard)
	stream, err := factory.Open(ctx, auth.Principal{AccountID: account}, &http.Cookie{Value: "opaque"})
	if err != nil {
		t.Fatal(err)
	}
	select {
	case delivery := <-stream.Events():
		if delivery.Unavailable || !stream.Current(delivery.State) || checks.Load() != 1 {
			t.Fatal("prepared delivery missing")
		}
	case <-time.After(2 * time.Second):
		t.Fatal("delivery timed out")
	}
	if _, err := factory.Open(ctx, auth.Principal{AccountID: account}, &http.Cookie{Value: "opaque"}); err == nil {
		t.Fatal("admission limit ignored")
	}
	stream.Close()
	stream.Close()
	if stream.RequestRefresh() {
		t.Fatal("closed stream accepted refresh")
	}
	select {
	case _, open := <-stream.Events():
		if open {
			t.Fatal("closed stream delivered an unexpected value")
		}
	case <-time.After(time.Second):
		t.Fatal("preparation worker did not stop")
	}
	if _, err := factory.Open(ctx, auth.Principal{AccountID: "invalid"}, &http.Cookie{Value: "opaque"}); err == nil {
		t.Fatal("invalid account accepted")
	}
}
