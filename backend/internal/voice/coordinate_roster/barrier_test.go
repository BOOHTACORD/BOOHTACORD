package coordinateroster

import (
	"context"
	"sync/atomic"
	"testing"
	"time"

	roster "voice-platform/backend/internal/voice/list_connected_participants"
)

type blockingLister struct {
	calls            atomic.Int32
	started, release chan struct{}
}

func (l *blockingLister) List(ctx context.Context, _ string) (roster.Result, error) {
	if l.calls.Add(1) == 1 {
		close(l.started)
		select {
		case <-l.release:
		case <-ctx.Done():
			return roster.Result{}, ctx.Err()
		}
	}
	return roster.Result{Channels: []roster.ChannelRoster{{ChannelID: accountA, Participants: []roster.Participant{{AccountID: accountB, DisplayName: "Current"}}}}}, nil
}

func TestHintDuringInitialReadCannotBeLost(t *testing.T) {
	lister := &blockingLister{started: make(chan struct{}), release: make(chan struct{})}
	coordinator, _, _ := fixture(t, lister)
	sub, err := coordinator.Subscribe(accountA)
	if err != nil {
		t.Fatal(err)
	}
	defer sub.Close()
	select {
	case <-lister.started:
	case <-time.After(time.Second):
		t.Fatal("initial read not started")
	}
	coordinator.Invalidate()
	close(lister.release)
	state := receive(t, sub)
	if state.Unavailable || lister.calls.Load() < 2 {
		t.Fatalf("invalidation missed: state=%+v calls=%d", state, lister.calls.Load())
	}
}

func TestConfigurationAndSubscriberLimit(t *testing.T) {
	lister := &fakeLister{}
	if _, err := New(Config{}, lister, nil); err == nil {
		t.Fatal("invalid config accepted")
	}
	coordinator, _, _ := fixture(t, lister)
	for _, id := range []string{accountA, accountB, "33333333-3333-4333-8333-333333333333", "44444444-4444-4444-8444-444444444444"} {
		if _, err := coordinator.Subscribe(id); err != nil {
			t.Fatal(err)
		}
	}
	if _, err := coordinator.Subscribe("55555555-5555-4555-8555-555555555555"); err == nil {
		t.Fatal("account budget exceeded")
	}
	if _, err := coordinator.Subscribe("bad"); err == nil {
		t.Fatal("invalid account accepted")
	}
}

func TestLastSubscriberCancelsInFlightRead(t *testing.T) {
	stopped := make(chan struct{})
	started := make(chan struct{})
	lister := cancelLister{started: started, stopped: stopped}
	coordinator, _, _ := fixture(t, lister)
	sub, err := coordinator.Subscribe(accountA)
	if err != nil {
		t.Fatal(err)
	}
	select {
	case <-started:
	case <-time.After(time.Second):
		t.Fatal("read did not start")
	}
	sub.Close()
	select {
	case <-stopped:
	case <-time.After(250 * time.Millisecond):
		t.Fatal("orphaned read was not canceled")
	}
}

type cancelLister struct{ started, stopped chan struct{} }

func (l cancelLister) List(ctx context.Context, _ string) (roster.Result, error) {
	close(l.started)
	<-ctx.Done()
	close(l.stopped)
	return roster.Result{}, ctx.Err()
}
