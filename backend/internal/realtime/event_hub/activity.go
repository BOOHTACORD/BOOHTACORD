package eventhub

import (
	"sort"
	"time"

	"github.com/google/uuid"
)

const DefaultIdleAfter = 5 * time.Minute

// ReportActivity advances only the authenticated socket's activity timestamp.
// An account returns to online when any of its connected clients becomes active.
func (hub *Hub) ReportActivity(subscription *Subscription, at time.Time) {
	if hub == nil || subscription == nil || subscription.accountID == "" {
		return
	}
	if at.IsZero() {
		at = time.Now()
	}
	hub.mu.Lock()
	defer hub.mu.Unlock()
	connections := hub.accountConnections[subscription.accountID]
	if _, connected := connections[subscription]; !connected {
		return
	}
	// Bound authenticated activity traffic to at most one update per connection
	// every five seconds. The client also throttles, but the server is authoritative.
	if !subscription.lastActivity.IsZero() && at.Sub(subscription.lastActivity) < 5*time.Second {
		return
	}
	subscription.lastActivity = at
	if hub.presenceStates[subscription.accountID] != "online" {
		hub.presenceStates[subscription.accountID] = "online"
		hub.publishLocked(presenceChanged(subscription.accountID, "active", at))
	}
}

func (hub *Hub) IdleAccountsSnapshot() []string {
	if hub == nil {
		return nil
	}
	hub.mu.Lock()
	defer hub.mu.Unlock()
	accounts := make([]string, 0)
	for accountID, state := range hub.presenceStates {
		if state == "idle" {
			accounts = append(accounts, accountID)
		}
	}
	sort.Strings(accounts)
	return accounts
}

// SweepIdle publishes one transition for each account whose connected clients
// have all been inactive for the requested interval.
func (hub *Hub) SweepIdle(now time.Time, idleAfter time.Duration) int {
	if hub == nil {
		return 0
	}
	if now.IsZero() {
		now = time.Now()
	}
	if idleAfter <= 0 {
		idleAfter = DefaultIdleAfter
	}
	hub.mu.Lock()
	defer hub.mu.Unlock()
	changed := 0
	for accountID, connections := range hub.accountConnections {
		if hub.presenceStates[accountID] != "online" {
			continue
		}
		last := latestActivity(connections)
		if !last.IsZero() && !last.After(now.Add(-idleAfter)) {
			hub.presenceStates[accountID] = "idle"
			hub.publishLocked(presenceChanged(accountID, "idle", now))
			changed++
		}
	}
	return changed
}

func (hub *Hub) PresenceState(accountID string) string {
	if hub == nil || accountID == "" {
		return "offline"
	}
	hub.mu.Lock()
	defer hub.mu.Unlock()
	if hub.connections[accountID] == 0 {
		return "offline"
	}
	state := hub.presenceStates[accountID]
	if state == "idle" {
		return "idle"
	}
	return "online"
}

// LastActivity returns the newest activity timestamp across connected clients.
// It is consumed only by the local AFK routing worker; identifiers stay in memory.
func (hub *Hub) LastActivity(accountID string) (time.Time, bool) {
	if hub == nil || accountID == "" {
		return time.Time{}, false
	}
	hub.mu.Lock()
	defer hub.mu.Unlock()
	connections := hub.accountConnections[accountID]
	if len(connections) == 0 {
		return time.Time{}, false
	}
	return latestActivity(connections), true
}

func (hub *Hub) IdleSince(accountID string) (time.Time, bool) {
	if hub == nil || accountID == "" {
		return time.Time{}, false
	}
	hub.mu.Lock()
	defer hub.mu.Unlock()
	if hub.presenceStates[accountID] != "idle" {
		return time.Time{}, false
	}
	at := latestActivity(hub.accountConnections[accountID])
	return at, !at.IsZero()
}

func latestActivity(connections map[*Subscription]struct{}) time.Time {
	var latest time.Time
	for connection := range connections {
		if connection.lastActivity.After(latest) {
			latest = connection.lastActivity
		}
	}
	return latest
}

func presenceChanged(accountID, state string, at time.Time) Event {
	presence, activity := "online", "active"
	if state == "offline" {
		presence, activity = "offline", ""
	} else if state == "idle" {
		activity = "idle"
	}
	payload := map[string]any{"user_id": accountID, "presence": presence}
	if activity != "" {
		payload["activity_state"] = activity
	}
	return Event{EventID: uuid.NewString(), Kind: "presence.changed", OccurredAt: at.UTC(), Payload: payload}
}
