package eventhub

import (
	"testing"
	"time"
)

func TestUnconfirmedConnectionCannotCauseImmediateIdleOrAFK(t *testing.T) {
	hub := New(16)
	old := hub.SubscribeAccountAt("account", Event{}, time.Now().Add(-6*time.Minute))
	defer old.Close()
	unconfirmed := hub.SubscribeAccountWithCapabilities("account", Event{}, []string{"confirmed_activity_v1"})
	defer unconfirmed.Close()
	hub.SweepIdle(time.Now(), DefaultIdleAfter)
	if state := hub.PresenceState("account"); state != "online" {
		t.Fatalf("unknown recent connection must receive its timeout: %q", state)
	}
	if _, ok := hub.LastActivity("account"); ok {
		t.Fatal("unknown activity is not evidence for an AFK move")
	}
}

func TestLegacyConnectionRetainsExistingOnlineBehavior(t *testing.T) {
	hub := New(16)
	old := hub.SubscribeAccountAt("account", Event{}, time.Now().Add(-6*time.Minute))
	defer old.Close()
	hub.SweepIdle(time.Now(), DefaultIdleAfter)
	legacy := hub.SubscribeAccountWithCapabilities("account", Event{}, nil)
	defer legacy.Close()
	if got := hub.PresenceState("account"); got != "online" {
		t.Fatalf("legacy connection behavior changed: %q", got)
	}
}

func TestUnconfirmedConnectionIsNotEvidenceForAFK(t *testing.T) {
	hub := New(16)
	old := hub.SubscribeAccountAt("account", Event{}, time.Now().Add(-6*time.Minute))
	hub.SweepIdle(time.Now(), DefaultIdleAfter)
	unconfirmed := hub.SubscribeAccountWithCapabilities("account", Event{}, []string{"confirmed_activity_v1"})
	defer unconfirmed.Close()
	old.Close()
	if _, ok := hub.LastActivity("account"); ok {
		t.Fatal("unknown activity must not be interpreted as confirmed inactivity")
	}
}

func TestUnconfirmedConnectionTimesOutWithoutImmediateIdleOrFalseAFK(t *testing.T) {
	hub := New(16)
	old := hub.SubscribeAccountAt("account", Event{}, time.Now().Add(-time.Minute))
	unconfirmed := hub.SubscribeAccountWithCapabilities("account", Event{}, []string{"confirmed_activity_v1"})
	defer unconfirmed.Close()
	old.Close()
	if state := hub.PresenceState("account"); state != "online" {
		t.Fatalf("new unknown session should not immediately become idle: %q", state)
	}
	if _, ok := hub.LastActivity("account"); ok {
		t.Fatal("unknown input must not provide AFK activity evidence")
	}
	hub.SweepIdle(time.Now().Add(DefaultIdleAfter+time.Second), DefaultIdleAfter)
	if state := hub.PresenceState("account"); state != "idle" {
		t.Fatalf("unknown session must not remain online indefinitely: %q", state)
	}
}

func TestConfirmedInactivityStartsAFKClockOnlyOnce(t *testing.T) {
	hub := New(16)
	old := hub.SubscribeAccountAt("account", Event{}, time.Now().Add(-6*time.Minute))
	defer old.Close()
	hub.SweepIdle(time.Now(), DefaultIdleAfter)
	other := hub.SubscribeAccountWithCapabilities("account", Event{}, []string{"confirmed_activity_v1"})
	defer other.Close()
	first := time.Now()
	hub.ReportInactive(other, first)
	if state := hub.PresenceState("account"); state != "idle" {
		t.Fatalf("confirmed inactivity revived an idle account: %q", state)
	}
	last, ok := hub.LastActivity("account")
	if !ok || !last.Equal(first) {
		t.Fatalf("confirmed inactivity clock = %v, %v", last, ok)
	}
	hub.ReportInactive(other, first.Add(2*time.Minute))
	if last, ok = hub.LastActivity("account"); !ok || !last.Equal(first) {
		t.Fatalf("repeated inactivity extended the AFK clock: %v, %v", last, ok)
	}
	hub.ReportActivity(other, first.Add(2*time.Minute))
	if state := hub.PresenceState("account"); state != "online" {
		t.Fatalf("confirmed activity did not restore online: %q", state)
	}
}

func TestInactivityRequiresCapabilityAndLiveSubscription(t *testing.T) {
	hub := New(16)
	legacy := hub.SubscribeAccountWithCapabilities("account", Event{}, nil)
	hub.mu.Lock()
	legacy.lastActivity = time.Time{}
	hub.mu.Unlock()
	hub.ReportInactive(legacy, time.Now())
	if _, ok := hub.LastActivity("account"); ok {
		t.Fatal("legacy socket accepted inactivity")
	}
	legacy.Close()
	hub.ReportInactive(legacy, time.Now())
	if state := hub.PresenceState("account"); state != "offline" {
		t.Fatalf("closed socket changed state: %q", state)
	}
}

func TestInitialIdleRequiresConfirmedActivityCapability(t *testing.T) {
	hub := New(8)
	socket := hub.SubscribeAccountWithCapabilities("account", Event{}, []string{"initial_idle_v1"})
	defer socket.Close()
	if got := hub.PresenceState("account"); got != "online" {
		t.Fatalf("unnegotiated initial idle changed legacy state: %q", got)
	}
}
