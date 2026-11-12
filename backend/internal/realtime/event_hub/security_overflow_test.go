package eventhub

import (
	"fmt"
	"testing"
)

func TestOverflowRetainsSessionAndPermissionEventsForAuthorizedClients(t *testing.T) {
	hub := New(64)
	owner := hub.SubscribeAccountWithCapabilities("owner", Event{}, []string{"role_permissions_v1"})
	other := hub.SubscribeAccountWithCapabilities("other", Event{}, []string{"role_permissions_v1"})
	defer owner.Close()
	defer other.Close()
	hub.PublishToAccounts([]string{"owner"}, Event{EventID: "early", Kind: "session.state_changed"})
	for i := 0; i < 64; i++ {
		hub.PublishToAccounts([]string{"owner"}, Event{EventID: fmt.Sprint(i), Kind: "message.updated"})
	}
	hub.PublishToAccountsTransient([]string{"owner"}, Event{EventID: "private", Kind: "auth.permissions.invalidated"})
	hub.Publish(Event{EventID: "role", Kind: "role.permissions.updated"})
	if !owner.AcknowledgeOverflow() {
		t.Fatal("unexpected saturation")
	}
	for _, want := range []string{"early", "private", "role"} {
		select {
		case event := <-owner.Events():
			if event.EventID != want {
				t.Fatalf("got %q, want %q", event.EventID, want)
			}
		default:
			t.Fatalf("missing %s", want)
		}
	}
	select {
	case event := <-other.Events():
		if event.EventID != "role" {
			t.Fatalf("private event leaked: %q", event.EventID)
		}
	default:
		t.Fatal("broadcast missing for another capable subscriber")
	}
}

func TestSecurityOverflowSignalsCloseWhenRetentionIsSaturated(t *testing.T) {
	hub := New(1)
	owner := hub.SubscribeAccountWithCapabilities("owner", Event{}, []string{"role_permissions_v1"})
	defer owner.Close()
	hub.PublishToAccounts([]string{"owner"}, Event{EventID: "one", Kind: "message.updated"})
	hub.PublishToAccounts([]string{"owner"}, Event{EventID: "two", Kind: "message.updated"})
	hub.PublishToAccounts([]string{"owner"}, Event{EventID: "session", Kind: "session.state_changed"})
	hub.PublishToAccountsTransient([]string{"owner"}, Event{EventID: "permission", Kind: "auth.permissions.invalidated"})
	if owner.AcknowledgeOverflow() {
		t.Fatal("lost critical event without a close requirement")
	}
}

func TestOverflowStillHonorsPermissionCapability(t *testing.T) {
	hub := New(1)
	legacy := hub.Subscribe("legacy")
	defer legacy.Close()
	hub.PublishToAccounts([]string{"legacy"}, Event{EventID: "one", Kind: "message.updated"})
	hub.PublishToAccounts([]string{"legacy"}, Event{EventID: "two", Kind: "message.updated"})
	hub.Publish(Event{EventID: "role", Kind: "role.permissions.updated"})
	hub.PublishToAccountsTransient([]string{"legacy"}, Event{EventID: "private", Kind: "auth.permissions.invalidated"})
	if !legacy.AcknowledgeOverflow() {
		t.Fatal("unsupported hints caused saturation")
	}
	select {
	case event := <-legacy.Events():
		t.Fatalf("unsupported event: %q", event.Kind)
	default:
	}
}
