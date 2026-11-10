package coordinateroster

import (
	"context"
	"errors"
	"sync/atomic"
	"testing"
	"time"

	roster "voice-platform/backend/internal/voice/list_connected_participants"
)

const accountA = "11111111-1111-4111-8111-111111111111"
const accountB = "22222222-2222-4222-8222-222222222222"

type fakeLister struct {
	mode  atomic.Int32
	calls atomic.Int32
}

func (f *fakeLister) List(_ context.Context, account string) (roster.Result, error) {
	f.calls.Add(1)
	if f.mode.Load() == 2 {
		return roster.Result{}, errors.New("private database error")
	}
	result := roster.Result{Channels: []roster.ChannelRoster{{ChannelID: account}}}
	if f.mode.Load() == 1 {
		result.Channels[0].Participants = []roster.Participant{{AccountID: account, DisplayName: "Test"}}
	}
	return result, nil
}

func fixture(t *testing.T, lister Lister) (*Coordinator, chan struct{}, context.CancelFunc) {
	t.Helper()
	changes := make(chan struct{}, 1)
	coordinator, err := New(Config{Workers: 2, MaxAccounts: 4, MaxSubscribers: 8, PollInterval: time.Hour, ReadTimeout: time.Second, MaxSnapshotBytes: 4096}, lister, changes)
	if err != nil {
		t.Fatal(err)
	}
	ctx, cancel := context.WithCancel(context.Background())
	go coordinator.Run(ctx)
	t.Cleanup(cancel)
	return coordinator, changes, cancel
}

func receive(t *testing.T, sub *Subscription) State {
	t.Helper()
	select {
	case value, ok := <-sub.Events():
		if !ok {
			t.Fatal("subscription closed")
		}
		return value
	case <-time.After(2 * time.Second):
		t.Fatal("timed out")
		return State{}
	}
}

func TestSharedAccountChangesAndUnavailableRecovery(t *testing.T) {
	lister := &fakeLister{}
	coordinator, changes, _ := fixture(t, lister)
	a, err := coordinator.Subscribe(accountA)
	if err != nil {
		t.Fatal(err)
	}
	defer a.Close()
	first := receive(t, a)
	if first.Unavailable || first.Revision != 1 || len(first.Roster.Channels) != 1 {
		t.Fatalf("first: %+v", first)
	}
	sibling, err := coordinator.Subscribe(accountA)
	if err != nil {
		t.Fatal(err)
	}
	defer sibling.Close()
	initial := receive(t, sibling)
	if initial.Generation != first.Generation || initial.Revision != first.Revision {
		t.Fatalf("sibling: %+v", initial)
	}
	other, err := coordinator.Subscribe(accountB)
	if err != nil {
		t.Fatal(err)
	}
	defer other.Close()
	if got := receive(t, other); got.Roster.Channels[0].ChannelID != accountB {
		t.Fatal("account roster crossed scope")
	}
	lister.mode.Store(1)
	changes <- struct{}{}
	one, two := receive(t, a), receive(t, sibling)
	if one.Revision <= first.Revision || one.Revision != two.Revision || len(one.Roster.Channels[0].Participants) != 1 {
		t.Fatalf("changes: %+v %+v", one, two)
	}
	receive(t, other)
	changes <- struct{}{}
	select {
	case value := <-a.Events():
		t.Fatalf("unchanged broadcast: %+v", value)
	case <-time.After(100 * time.Millisecond):
	}
	lister.mode.Store(2)
	changes <- struct{}{}
	if failure := receive(t, a); !failure.Unavailable || failure.Revision <= one.Revision {
		t.Fatalf("unavailable: %+v", failure)
	}
	lister.mode.Store(0)
	changes <- struct{}{}
	if recovery := receive(t, a); recovery.Unavailable || len(recovery.Roster.Channels[0].Participants) != 0 {
		t.Fatalf("recovery: %+v", recovery)
	}
}
