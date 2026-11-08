package coordinateroster

import (
	"testing"
	"time"
)

func TestSlowSubscriberGetsLatestAndCannotMutateOtherRecipients(t *testing.T) {
	lister := &fakeLister{}
	c, _, _ := fixture(t, lister)
	fast, err := c.Subscribe(accountA)
	if err != nil {
		t.Fatal(err)
	}
	defer fast.Close()
	receive(t, fast)
	slow, err := c.Subscribe(accountA)
	if err != nil {
		t.Fatal(err)
	}
	defer slow.Close()
	// Ensure slow has an initial queued snapshot before replacing it.
	deadline := time.Now().Add(time.Second)
	for lister.calls.Load() < 2 && time.Now().Before(deadline) {
		time.Sleep(time.Millisecond)
	}
	lister.mode.Store(1)
	c.Invalidate()
	latest := receive(t, fast)
	queued := receive(t, slow)
	if queued.Revision != latest.Revision || len(queued.Roster.Channels[0].Participants) != 1 {
		t.Fatalf("slow subscriber: %+v", queued)
	}
	latest.Roster.Channels[0].Participants[0].DisplayName = "mutated"
	if queued.Roster.Channels[0].Participants[0].DisplayName != "Test" {
		t.Fatal("subscribers share mutable roster data")
	}
}

func TestShutdownClosesSubscribersAndStopsAdmission(t *testing.T) {
	lister := &fakeLister{}
	c, _, cancel := fixture(t, lister)
	sub, err := c.Subscribe(accountA)
	if err != nil {
		t.Fatal(err)
	}
	receive(t, sub)
	cancel()
	select {
	case _, ok := <-sub.Events():
		if ok {
			t.Fatal("subscriber not closed")
		}
	case <-time.After(time.Second):
		t.Fatal("shutdown blocked")
	}
	sub.Close()
	if _, err := c.Subscribe(accountA); err == nil {
		t.Fatal("accepted subscriber after shutdown")
	}
}

func TestNoSubscribersMeansNoRosterReads(t *testing.T) {
	lister := &fakeLister{}
	c, _, _ := fixture(t, lister)
	c.Invalidate()
	time.Sleep(50 * time.Millisecond)
	if count := lister.calls.Load(); count != 0 {
		t.Fatalf("reads without subscribers: %d", count)
	}
}
