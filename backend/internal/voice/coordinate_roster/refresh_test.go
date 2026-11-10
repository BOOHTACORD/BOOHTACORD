package coordinateroster

import (
	"context"
	"sync/atomic"
	"testing"
	"time"

	roster "voice-platform/backend/internal/voice/list_connected_participants"
)

type proofLister struct{ changed atomic.Bool }

func (l *proofLister) List(context.Context, string) (roster.Result, error) {
	proof := "33333333-3333-4333-8333-333333333333"
	if l.changed.Load() {
		proof = "44444444-4444-4444-8444-444444444444"
	}
	return roster.Result{Channels: []roster.ChannelRoster{{ChannelID: accountA, Participants: []roster.Participant{{AccountID: accountB, LeaseID: proof, DisplayName: "Test"}}}}}, nil
}

func TestRefreshDiscardsQueuedStaleProof(t *testing.T) {
	lister := &proofLister{}
	c, _, _ := fixture(t, lister)
	sub, err := c.Subscribe(accountA)
	if err != nil {
		t.Fatal(err)
	}
	defer sub.Close()
	deadline := time.Now().Add(time.Second)
	for len(sub.Events()) == 0 && time.Now().Before(deadline) {
		time.Sleep(time.Millisecond)
	}
	if len(sub.Events()) == 0 {
		t.Fatal("initial state not queued")
	}
	lister.changed.Store(true)
	if !sub.RequestRefresh() {
		t.Fatal("refresh rejected")
	}
	state := receive(t, sub)
	if state.Roster.Channels[0].Participants[0].LeaseID != "44444444-4444-4444-8444-444444444444" {
		t.Fatal("stale queued proof was delivered")
	}
}

func TestRecipientCanRefreshChangedProofWithoutBroadcastingUnchangedRoster(t *testing.T) {
	lister := &proofLister{}
	c, _, _ := fixture(t, lister)
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
	lister.changed.Store(true)
	if !first.RequestRefresh() {
		t.Fatal("refresh rejected")
	}
	updated := receive(t, first)
	if updated.Revision != initial.Revision || updated.Roster.Channels[0].Participants[0].LeaseID == initial.Roster.Channels[0].Participants[0].LeaseID {
		t.Fatalf("proof refresh: %+v", updated)
	}
	select {
	case state := <-second.Events():
		t.Fatalf("unrelated duplicate: %+v", state)
	default:
	}
	first.Close()
	if first.RequestRefresh() {
		t.Fatal("closed subscription refreshed")
	}
}
