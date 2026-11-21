package eventhub

import "time"

const maxReconnectHistory = 4096

type reconnectEntry struct {
	at             time.Time
	inactivityOnly bool
	idle           bool
}

// rememberDisconnected runs under hub.mu. It retains only server-observed times.
func (hub *Hub) rememberDisconnected(account string, entry reconnectEntry) {
	if entry.at.IsZero() {
		return
	}
	if hub.reconnectHistory == nil {
		hub.reconnectHistory = make(map[string]reconnectEntry)
	}
	if _, exists := hub.reconnectHistory[account]; !exists && len(hub.reconnectHistory) >= maxReconnectHistory {
		var oldestID string
		var oldest time.Time
		for id, seen := range hub.reconnectHistory {
			if oldestID == "" || seen.at.Before(oldest) {
				oldestID, oldest = id, seen.at
			}
		}
		delete(hub.reconnectHistory, oldestID)
	}
	hub.reconnectHistory[account] = entry
}

func reconnectEvent(event Event, idle bool) Event {
	if !idle {
		return event
	}
	payload := make(map[string]any, len(event.Payload)+1)
	for key, value := range event.Payload {
		payload[key] = value
	}
	payload["activity_state"] = "idle"
	event.Payload = payload
	return event
}
