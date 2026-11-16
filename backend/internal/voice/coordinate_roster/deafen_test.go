package coordinateroster

import (
	"context"
	"sync/atomic"
	"testing"

	roster "voice-platform/backend/internal/voice/list_connected_participants"
)

type deafenLister struct{ deafened atomic.Bool }

func (l *deafenLister) List(context.Context, string) (roster.Result, error) {
	return roster.Result{Channels: []roster.ChannelRoster{{ChannelID: accountA, Participants: []roster.Participant{{AccountID: accountB, DisplayName: "Test", Deafened: l.deafened.Load()}}}}}, nil
}

func TestDeafenOnlyChangesNotifyAllSubscribers(t *testing.T) {
	lister := &deafenLister{}
	c, changes, _ := fixture(t, lister)
	first, err := c.Subscribe(accountA)
	if err != nil {
		t.Fatal(err)
	}
	defer first.Close()
	initial := receive(t, first)
	second, err := c.Subscribe(accountA)
	if err != nil {
		t.Fatal(err)
	}
	defer second.Close()
	receive(t, second)
	for _, deafened := range []bool{true, false} {
		lister.deafened.Store(deafened)
		changes <- struct{}{}
		one, two := receive(t, first), receive(t, second)
		if one.Revision <= initial.Revision || two.Revision != one.Revision || one.Roster.Channels[0].Participants[0].Deafened != deafened || two.Roster.Channels[0].Participants[0].Deafened != deafened {
			t.Fatalf("deafened=%v did not reach subscribers", deafened)
		}
		initial = one
	}
}
