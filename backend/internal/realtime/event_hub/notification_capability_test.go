package eventhub

import "testing"

func TestNotificationHintsArePrivateAndRequireOptedInClientProtocol(t *testing.T) {
	hub := New(8)
	legacy := hub.SubscribeAccountWithCapabilities("owner", Event{}, nil)
	current := hub.SubscribeAccountWithCapabilities("owner", Event{}, []string{"notifications_v1"})
	outsider := hub.SubscribeAccountWithCapabilities("outsider", Event{}, []string{"notifications_v1"})
	defer legacy.Close()
	defer current.Close()
	defer outsider.Close()
	for _, kind := range []string{"notification.queued", "notification.preferences_changed"} {
		hub.PublishToAccountsTransient([]string{"owner"}, Event{Kind: kind})
		select {
		case <-legacy.Events():
			t.Fatal("old client received unknown notification protocol")
		default:
		}
		select {
		case <-outsider.Events():
			t.Fatal("private notification hint leaked to another account")
		default:
		}
		select {
		case event := <-current.Events():
			if event.Kind != kind {
				t.Fatal(event.Kind)
			}
		default:
			t.Fatal("current client missed targeted hint")
		}
	}
}
