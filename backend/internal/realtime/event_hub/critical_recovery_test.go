package eventhub

import (
	"context"
	"errors"
	"fmt"
	"sync"
	"testing"
)

func TestJournalFailureRetainsAlreadyQueuedRevocation(t *testing.T) {
	hub := New(2)
	owner := hub.Subscribe("owner")
	defer owner.Close()
	hub.PublishToAccounts([]string{"owner"}, Event{EventID: "revoke", Kind: "voice.lease_revoked"})
	hub.SetJournal(&fakeJournal{err: errors.New("unavailable")})
	if err := hub.PublishToAccountsDurable(context.Background(), []string{"owner"}, Event{EventID: "another", Kind: "voice.lease_revoked"}); err == nil {
		t.Fatal("journal failure was hidden")
	}
	owner.AcknowledgeOverflow()
	select {
	case event := <-owner.Events():
		if event.EventID != "revoke" {
			t.Fatal("queued revoke was replaced")
		}
	default:
		t.Fatal("queued revoke was lost during journal failure")
	}
}

func TestCriticalQueueAtCapacityRequiresDurableRetry(t *testing.T) {
	hub := New(64)
	hub.SetJournal(&fakeJournal{})
	owner := hub.Subscribe("owner")
	defer owner.Close()
	for index := 0; index < 64; index++ {
		event := Event{EventID: fmt.Sprint(index), Kind: "voice.lease_revoked"}
		if err := hub.PublishToAccountsDurable(context.Background(), []string{"owner"}, event); err != nil {
			t.Fatalf("revocation %d: %v", index, err)
		}
	}
	last := Event{EventID: "last", Kind: "voice.lease_revoked"}
	if err := hub.PublishToAccountsDurable(context.Background(), []string{"owner"}, last); !errors.Is(err, ErrCriticalBackpressure) {
		t.Fatalf("expected explicit retry at capacity, got %v", err)
	}
	owner.AcknowledgeOverflow()
	for index := 0; index < 64; index++ {
		select {
		case event := <-owner.Events():
			if event.Kind != "voice.lease_revoked" {
				t.Fatalf("unexpected retained event %q", event.Kind)
			}
		default:
			t.Fatalf("missing retained revocation %d", index)
		}
	}
	if err := hub.PublishToAccountsDurable(context.Background(), []string{"owner"}, last); err != nil {
		t.Fatalf("retry after draining: %v", err)
	}
	select {
	case event := <-owner.Events():
		if event.Kind != "voice.lease_revoked" {
			t.Fatalf("unexpected retry event %q", event.Kind)
		}
	default:
		t.Fatal("retried revoke was not delivered")
	}
}

func TestRevocationRacingOverflowAcknowledgementIsRetained(t *testing.T) {
	for index := 0; index < 500; index++ {
		hub := New(1)
		owner := hub.Subscribe("owner")
		hub.PublishToAccounts([]string{"owner"}, Event{EventID: "one", Kind: "message.updated"})
		hub.PublishToAccounts([]string{"owner"}, Event{EventID: "two", Kind: "message.updated"})
		var tasks sync.WaitGroup
		tasks.Add(2)
		go func() { defer tasks.Done(); owner.AcknowledgeOverflow() }()
		go func() {
			defer tasks.Done()
			hub.PublishToAccounts([]string{"owner"}, Event{EventID: "revoke", Kind: "voice.lease_revoked"})
		}()
		tasks.Wait()
		select {
		case event := <-owner.Events():
			if event.EventID != "revoke" {
				t.Fatalf("iteration %d: unexpected event", index)
			}
		default:
			t.Fatalf("iteration %d: revoke lost", index)
		}
		owner.Close()
	}
}
