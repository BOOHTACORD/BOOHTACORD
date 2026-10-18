package eventhub

import "testing"

func TestPermissionEventsRequireRolePermissionsCapability(t *testing.T) {
	hub := New(2)
	legacy := hub.Subscribe("legacy")
	capable := hub.SubscribeAccountWithCapabilities("new", Event{}, []string{"role_permissions_v1"})
	defer legacy.Close()
	defer capable.Close()
	hub.Publish(Event{Kind: "role.permissions.updated"})
	select {
	case <-legacy.Events():
		t.Fatal("legacy client received unknown event")
	default:
	}
	select {
	case event := <-capable.Events():
		if event.Kind != "role.permissions.updated" {
			t.Fatalf("event = %#v", event)
		}
	default:
		t.Fatal("capable client missed event")
	}
}

func TestPreviewHintsRequirePreviewCapability(t *testing.T) {
	hub := New(2)
	legacy := hub.Subscribe("legacy")
	capable := hub.SubscribeAccountWithCapabilities("new", Event{}, []string{"screen_previews_v1"})
	defer legacy.Close()
	defer capable.Close()
	hub.PublishToAccounts([]string{"legacy", "new"}, Event{Kind: "screen_preview.updated"})
	select {
	case <-legacy.Events():
		t.Fatal("legacy client received unsupported preview event")
	default:
	}
	select {
	case event := <-capable.Events():
		if event.Kind != "screen_preview.updated" {
			t.Fatalf("event kind = %q", event.Kind)
		}
	default:
		t.Fatal("preview-aware client missed hint")
	}
}

func TestTransientScreenViewerHintsAreTargetedCapabilityGatedAndNotJournaled(t *testing.T) {
	hub := New(4)
	journal := &fakeJournal{}
	hub.SetJournal(journal)
	owner := hub.SubscribeAccountWithCapabilities("owner", Event{}, []string{"screen_viewers_v1"})
	other := hub.SubscribeAccountWithCapabilities("other", Event{}, []string{"screen_viewers_v1"})
	legacy := hub.Subscribe("legacy")
	defer owner.Close()
	defer other.Close()
	defer legacy.Close()

	hub.PublishToAccountsTransient([]string{"owner"}, Event{EventID: "viewer-change", Kind: "screen_viewers.changed", Payload: map[string]any{}})
	select {
	case event := <-owner.Events():
		if event.Kind != "screen_viewers.changed" || len(event.Payload) != 0 {
			t.Fatalf("event = %#v", event)
		}
	default:
		t.Fatal("owner missed transient viewer hint")
	}
	for name, subscription := range map[string]*Subscription{"other": other, "legacy": legacy} {
		select {
		case event := <-subscription.Events():
			t.Fatalf("%s received private hint: %#v", name, event)
		default:
		}
	}
	if journal.appended != 0 {
		t.Fatalf("transient hint was persisted %d times", journal.appended)
	}
}
