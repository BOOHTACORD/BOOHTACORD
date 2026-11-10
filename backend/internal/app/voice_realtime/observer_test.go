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

type rosterObserver struct {
	opened, closed, success, unavailable, initial, refresh atomic.Int32
}

func (o *rosterObserver) RosterWSOpened() { o.opened.Add(1) }
func (o *rosterObserver) RosterWSClosed() { o.closed.Add(1) }
func (o *rosterObserver) ObserveRosterWSDelivery(_ time.Duration, outcome string, initial bool) {
	if outcome == "success" {
		o.success.Add(1)
	}
	if outcome == "unavailable" {
		o.unavailable.Add(1)
	}
	if initial {
		o.initial.Add(1)
	}
}
func (o *rosterObserver) ObserveRosterWSRefresh(bool) { o.refresh.Add(1) }

func TestObserverTracksRosterLifecycleAndFirstFrame(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	c, err := coordinator.New(coordinator.Config{Workers: 1, MaxAccounts: 1, MaxSubscribers: 1, MaxSnapshotBytes: 4096, PollInterval: time.Hour, ReadTimeout: time.Second}, &lister{}, nil)
	if err != nil {
		t.Fatal(err)
	}
	go c.Run(ctx)
	pool, _ := prepared.New(1, time.Second)
	checker := guardFunc(func(context.Context, string, auth.Principal, roster.Result) error { return nil })
	observer := &rosterObserver{}
	stream, err := New(c, pool, checker, observer).Open(ctx, auth.Principal{AccountID: account}, &http.Cookie{Value: "opaque"})
	if err != nil {
		t.Fatal(err)
	}
	var delivery prepared.Delivery
	select {
	case delivery = <-stream.Events():
	case <-time.After(time.Second):
		t.Fatal("missing roster")
	}
	if err := stream.WithRoster(ctx, delivery.State, func(context.Context) error { return nil }); err != nil {
		t.Fatal(err)
	}
	notifier, ok := stream.(interface{ ObserveRosterUnavailable(time.Duration, bool) })
	if !ok {
		t.Fatal("unavailable frame cannot be observed")
	}
	notifier.ObserveRosterUnavailable(time.Millisecond, true)
	stream.Close()
	stream.Close()
	if observer.opened.Load() != 1 || observer.closed.Load() != 1 || observer.initial.Load() != 1 || observer.success.Load() != 1 || observer.unavailable.Load() != 1 {
		t.Fatalf("lifecycle counts: %+v", observer)
	}
}
