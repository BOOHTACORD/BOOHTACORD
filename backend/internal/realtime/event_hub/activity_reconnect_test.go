package eventhub

import (
	"fmt"
	"testing"
	"time"
)

func TestConfirmedActivityClientDoesNotReviveIdleAccountOnConnect(t *testing.T) {
	hub := New(16)
	start := time.Now().Add(-6 * time.Minute)
	old := hub.SubscribeAccountAt("account", Event{}, start)
	defer old.Close()
	hub.SweepIdle(time.Now(), DefaultIdleAfter)
	newSocket := hub.SubscribeAccountWithCapabilities("account", Event{}, []string{"confirmed_activity_v1"})
	defer newSocket.Close()
	if got := hub.PresenceState("account"); got != "idle" {
		t.Fatalf("connection without activity changed idle state to %q", got)
	}
	if last, ok := hub.LastActivity("account"); ok {
		t.Fatalf("unknown second connection must defer AFK: %v", last)
	}
	hub.ReportActivity(newSocket, time.Now())
	if got := hub.PresenceState("account"); got != "online" {
		t.Fatalf("confirmed activity must restore online, got %q", got)
	}
}

func TestFreshHubHonorsConfirmedInitialIdleWithoutTrustingClientTime(t *testing.T) {
	hub := New(8)
	before := time.Now()
	socket := hub.SubscribeAccountWithCapabilities("account", Event{}, []string{"confirmed_activity_v1", "initial_idle_v1"})
	defer socket.Close()
	if state := hub.PresenceState("account"); state != "idle" {
		t.Fatalf("initially idle client appeared %q", state)
	}
	last, ok := hub.LastActivity("account")
	if !ok || last.Before(before) {
		t.Fatalf("AFK clock must start from server time: %v, %v", last, ok)
	}
	hub.ReportActivity(socket, time.Now())
	if state := hub.PresenceState("account"); state != "online" {
		t.Fatalf("fresh input did not restore online: %q", state)
	}
}

func TestInitialIdleCannotDowngradeAnotherActiveSocket(t *testing.T) {
	hub := New(8)
	active := hub.SubscribeAccountAt("account", Event{}, time.Now())
	defer active.Close()
	idle := hub.SubscribeAccountWithCapabilities("account", Event{}, []string{"confirmed_activity_v1", "initial_idle_v1"})
	defer idle.Close()
	if state := hub.PresenceState("account"); state != "online" {
		t.Fatalf("idle second client changed active account to %q", state)
	}
	active.Close()
	if state := hub.PresenceState("account"); state != "idle" {
		t.Fatalf("last confirmed idle client appeared %q after active client left", state)
	}
}

func TestReconnectAfterLastSocketPreservesConfirmedIdle(t *testing.T) {
	hub := New(16)
	start := time.Now().Add(-6 * time.Minute)
	old := hub.SubscribeAccountAt("account", Event{}, start)
	hub.SweepIdle(time.Now(), DefaultIdleAfter)
	old.Close()
	if state := hub.PresenceState("account"); state != "offline" {
		t.Fatalf("account without sockets must be offline: %q", state)
	}
	reconnected := hub.SubscribeAccountWithCapabilities("account", Event{}, []string{"confirmed_activity_v1"})
	defer reconnected.Close()
	if state := hub.PresenceState("account"); state != "idle" {
		t.Fatalf("reconnection without activity must preserve idle: %q", state)
	}
	if last, ok := hub.LastActivity("account"); !ok || !last.Equal(start) {
		t.Fatalf("reconnection must preserve last confirmed time: %v, %v", last, ok)
	}
	hub.ReportActivity(reconnected, time.Now())
	if state := hub.PresenceState("account"); state != "online" {
		t.Fatalf("confirmed activity must restore online: %q", state)
	}
}

func TestReconnectPreservesIdleAfterConfirmedInactivity(t *testing.T) {
	hub := New(16)
	old := hub.SubscribeAccountAt("account", Event{}, time.Now().Add(-6*time.Minute))
	hub.SweepIdle(time.Now(), DefaultIdleAfter)
	other := hub.SubscribeAccountWithCapabilities("account", Event{}, []string{"confirmed_activity_v1"})
	hub.ReportInactive(other, time.Now())
	old.Close()
	other.Close()
	reconnected := hub.SubscribeAccountWithCapabilities("account", Event{}, []string{"confirmed_activity_v1"})
	defer reconnected.Close()
	if state := hub.PresenceState("account"); state != "idle" {
		t.Fatalf("inactive reconnect revived account: %q", state)
	}
	hub.ReportActivity(reconnected, time.Now())
	if state := hub.PresenceState("account"); state != "online" {
		t.Fatalf("immediate activity was suppressed: %q", state)
	}
}

func TestReconnectHistoryIsBounded(t *testing.T) {
	hub := New(1)
	now := time.Now()
	hub.mu.Lock()
	for i := 0; i < maxReconnectHistory; i++ {
		hub.rememberDisconnected(fmt.Sprintf("account-%04d", i), reconnectEntry{at: now.Add(time.Duration(i) * time.Second)})
	}
	hub.rememberDisconnected("new-account", reconnectEntry{at: now.Add(time.Hour)})
	if len(hub.reconnectHistory) != maxReconnectHistory {
		t.Fatalf("history size = %d", len(hub.reconnectHistory))
	}
	if _, exists := hub.reconnectHistory["account-0000"]; exists {
		t.Fatal("oldest entry was not evicted")
	}
	hub.mu.Unlock()
}
