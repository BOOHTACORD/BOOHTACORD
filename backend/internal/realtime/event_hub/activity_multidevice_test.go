package eventhub

import (
	"sync"
	"testing"
	"time"
)

func TestActivityFromOneConnectionPreventsIdleAndSurvivesOtherClose(t *testing.T) {
	hub := New(16)
	started := time.Now().Add(-6 * time.Minute)
	idle := hub.SubscribeAccountAt("account", Event{}, started)
	active := hub.SubscribeAccountAt("account", Event{}, started)
	now := time.Now()
	hub.ReportActivity(active, now)
	if hub.SweepIdle(now, DefaultIdleAfter) != 0 {
		t.Fatal("one active connection must prevent an idle transition")
	}
	if last, ok := hub.LastActivity("account"); !ok || !last.Equal(now) {
		t.Fatalf("aggregated activity = %v, %v", last, ok)
	}
	idle.Close()
	if hub.PresenceState("account") != "online" {
		t.Fatal("closing the inactive connection must not disturb the active one")
	}
	active.Close()
	if hub.PresenceState("account") != "offline" {
		t.Fatal("closing the last connection must mark the account offline")
	}
}

func TestClosedConnectionCannotRefreshAnotherConnection(t *testing.T) {
	hub := New(16)
	started := time.Now().Add(-6 * time.Minute)
	closed := hub.SubscribeAccountAt("account", Event{}, started)
	remaining := hub.SubscribeAccountAt("account", Event{}, started)
	closed.Close()
	hub.ReportActivity(closed, time.Now())
	last, ok := hub.LastActivity("account")
	if !ok || !last.Equal(started) {
		t.Fatalf("closed socket refreshed activity: %v, %v", last, ok)
	}
	remaining.Close()
}

func TestConcurrentActivityAndSweepRemainRaceFree(t *testing.T) {
	hub := New(128)
	start := time.Now().Add(-6 * time.Minute)
	subscription := hub.SubscribeAccountAt("account", Event{}, start)
	defer subscription.Close()
	var workers sync.WaitGroup
	for i := 0; i < 8; i++ {
		workers.Add(1)
		go func() {
			defer workers.Done()
			for j := 0; j < 100; j++ {
				hub.SweepIdle(time.Now(), DefaultIdleAfter)
				hub.ReportActivity(subscription, time.Now())
			}
		}()
	}
	workers.Wait()
	if hub.PresenceState("account") != "online" {
		t.Fatal("recent confirmed activity should remain online")
	}
}
