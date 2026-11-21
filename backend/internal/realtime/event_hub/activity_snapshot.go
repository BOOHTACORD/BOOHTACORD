package eventhub

import "time"

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
	for connection := range connections {
		if connection.lastActivity.IsZero() {
			return time.Time{}, false
		}
	}
	last := latestActivity(connections)
	return last, !last.IsZero()
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

func allPresenceIdle(connections map[*Subscription]struct{}, cutoff time.Time) bool {
	if len(connections) == 0 {
		return false
	}
	for connection := range connections {
		if connection.initiallyIdle && connection.inactivityOnly {
			continue
		}
		observed := connection.lastActivity
		if observed.IsZero() {
			observed = connection.connectedAt
		}
		if observed.IsZero() || observed.After(cutoff) {
			return false
		}
	}
	return true
}
