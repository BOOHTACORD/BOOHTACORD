package eventhub

import (
	"testing"
	"time"
)

func TestIdlePresenceTransitionsAndActivityRefresh(t *testing.T) {
	hub := New(8)
	started := time.Date(2026, 11, 14, 10, 0, 0, 0, time.UTC)
	subscription := hub.SubscribeAccountAt("account-1", Event{}, started)
	if got := hub.PresenceState("account-1"); got != "online" {
		t.Fatalf("initial state = %q", got)
	}
	if changed := hub.SweepIdle(started.Add(5*time.Minute), 5*time.Minute); changed != 1 {
		t.Fatalf("idle transitions = %d", changed)
	}
	if got := hub.PresenceState("account-1"); got != "idle" {
		t.Fatalf("state after inactivity = %q", got)
	}
	if got, ok := hub.IdleSince("account-1"); !ok || !got.Equal(started) {
		t.Fatalf("idle since = %v, %v", got, ok)
	}
	hub.ReportActivity(subscription, started.Add(6*time.Minute))
	if got := hub.PresenceState("account-1"); got != "online" {
		t.Fatalf("state after activity = %q", got)
	}
	if _, ok := hub.IdleSince("account-1"); ok {
		t.Fatal("active account still reports idle time")
	}
}

func TestIdlePresenceAggregatesMultipleClientsAndGoesOfflineAfterLastClose(t *testing.T) {
	hub := New(8)
	started := time.Date(2026, 11, 14, 10, 0, 0, 0, time.UTC)
	first := hub.SubscribeAccountAt("account-1", Event{}, started)
	second := hub.SubscribeAccountAt("account-1", Event{}, started)
	if changed := hub.SweepIdle(started.Add(5*time.Minute), 5*time.Minute); changed != 1 {
		t.Fatalf("idle transitions = %d", changed)
	}
	hub.ReportActivity(second, started.Add(6*time.Minute))
	if got := hub.PresenceState("account-1"); got != "online" {
		t.Fatalf("one active client state = %q", got)
	}
	if changed := hub.SweepIdle(started.Add(11*time.Minute), 5*time.Minute); changed != 1 {
		t.Fatalf("second idle transitions = %d", changed)
	}
	first.Close()
	if got := hub.PresenceState("account-1"); got != "idle" {
		t.Fatalf("remaining inactive client state = %q", got)
	}
	second.Close()
	if got := hub.PresenceState("account-1"); got != "offline" {
		t.Fatalf("state after last close = %q", got)
	}
}
