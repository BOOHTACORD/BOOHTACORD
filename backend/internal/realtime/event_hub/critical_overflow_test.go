package eventhub

import (
	"context"
	"fmt"
	"testing"
	"time"
)

func TestRevocationSurvivesFullQueueUntilResynchronization(t *testing.T) {
	hub := New(64)
	owner := hub.Subscribe("owner")
	other := hub.Subscribe("other")
	defer owner.Close()
	defer other.Close()
	for index := 0; index < 65; index++ {
		hub.PublishToAccounts([]string{"owner"}, Event{EventID: fmt.Sprint(index), Kind: "message.updated"})
	}
	select {
	case <-owner.Overflowed():
	case <-time.After(time.Second):
		t.Fatal("ordinary queue did not overflow")
	}
	hub.PublishToAccounts([]string{"owner"}, Event{EventID: "revoked", Kind: "voice.lease_revoked"})
	owner.AcknowledgeOverflow()
	select {
	case event := <-owner.Events():
		if event.Kind != "voice.lease_revoked" || event.EventID != "revoked" {
			t.Fatalf("wrong event survived overflow: %q", event.Kind)
		}
	case <-time.After(time.Second):
		t.Fatal("lease revocation disappeared during overflow")
	}
	select {
	case event := <-other.Events():
		t.Fatalf("private event reached another subscriber: %q", event.Kind)
	default:
	}
}

func TestQueuedAndLateRevocationsSurviveOverflow(t *testing.T) {
	hub := New(2)
	owner := hub.Subscribe("owner")
	defer owner.Close()
	hub.PublishToAccounts([]string{"owner"}, Event{EventID: "first", Kind: "voice.lease_revoked"})
	hub.PublishToAccounts([]string{"owner"}, Event{EventID: "message", Kind: "message.updated"})
	hub.PublishToAccounts([]string{"owner"}, Event{EventID: "overflow", Kind: "message.updated"})
	hub.PublishToAccounts([]string{"owner"}, Event{EventID: "second", Kind: "voice.lease_revoked"})
	owner.AcknowledgeOverflow()
	for _, id := range []string{"first", "second"} {
		select {
		case event := <-owner.Events():
			if event.EventID != id || event.Kind != "voice.lease_revoked" {
				t.Fatalf("unexpected retained event %q", event.Kind)
			}
		case <-time.After(time.Second):
			t.Fatalf("missing retained revocation %q", id)
		}
	}
}

func TestFullCriticalBufferReturnsErrorForDurableRetry(t *testing.T) {
	hub := New(1)
	hub.SetJournal(&fakeJournal{})
	owner := hub.Subscribe("owner")
	defer owner.Close()
	hub.PublishToAccounts([]string{"owner"}, Event{EventID: "message", Kind: "message.updated"})
	hub.PublishToAccounts([]string{"owner"}, Event{EventID: "overflow", Kind: "message.updated"})
	first := Event{EventID: "first", Kind: "voice.lease_revoked"}
	second := Event{EventID: "second", Kind: "voice.lease_revoked"}
	if err := hub.PublishToAccountsDurable(context.Background(), []string{"owner"}, first); err != nil {
		t.Fatalf("first revocation: %v", err)
	}
	if err := hub.PublishToAccountsDurable(context.Background(), []string{"owner"}, second); err == nil {
		t.Fatal("full critical buffer falsely acknowledged delivery")
	}
	owner.AcknowledgeOverflow()
	<-owner.Events()
	if err := hub.PublishToAccountsDurable(context.Background(), []string{"owner"}, second); err != nil {
		t.Fatalf("retry after drain failed: %v", err)
	}
	select {
	case event := <-owner.Events():
		if event.Kind != "voice.lease_revoked" {
			t.Fatalf("wrong retry event %q", event.Kind)
		}
	case <-time.After(time.Second):
		t.Fatal("retry did not reach subscriber")
	}
}
