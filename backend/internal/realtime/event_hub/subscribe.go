package eventhub

import "time"

func (hub *Hub) Subscribe(accountIDs ...string) *Subscription {
	accountID := ""
	if len(accountIDs) > 0 {
		accountID = accountIDs[0]
	}
	return hub.subscribe(accountID, nil, nil, time.Now())
}

func (hub *Hub) SubscribeAccount(accountID string, onlineEvent Event) *Subscription {
	return hub.subscribe(accountID, &onlineEvent, nil, time.Now())
}

func (hub *Hub) subscribe(accountID string, onlineEvent *Event, capabilities map[string]struct{}, at time.Time) *Subscription {
	guard := hub.activityGuard(accountID)
	guard.Lock()
	defer guard.Unlock()
	subscription := &Subscription{hub: hub, accountID: accountID, capabilities: capabilities, lastActivity: at, connectedAt: at, events: make(chan Event, hub.queueSize), overflowed: make(chan struct{}, 1)}
	hub.mu.Lock()
	hub.subscribers[subscription] = struct{}{}
	if hub.broken {
		subscription.dropped = true
		subscription.overflowed <- struct{}{}
	}
	if accountID != "" {
		subscription.becameOnline = hub.connections[accountID] == 0
		_, confirmedActivity := capabilities["confirmed_activity_v1"]
		_, initialIdle := capabilities["initial_idle_v1"]
		initialIdle = confirmedActivity && initialIdle
		subscription.initiallyIdle = initialIdle
		unconfirmed := confirmedActivity && !subscription.becameOnline
		idleReconnect := false
		if unconfirmed {
			if initialIdle {
				subscription.inactivityOnly = true
			} else {
				subscription.lastActivity = time.Time{}
			}
		} else if confirmedActivity {
			if initialIdle {
				subscription.inactivityOnly = true
				idleReconnect = true
			} else if previous, ok := hub.reconnectHistory[accountID]; ok {
				subscription.lastActivity = previous.at
				subscription.inactivityOnly = previous.inactivityOnly
				idleReconnect = previous.idle || !previous.at.After(at.Add(-DefaultIdleAfter))
			}
		}
		delete(hub.reconnectHistory, accountID)
		hub.connections[accountID]++
		if hub.accountConnections[accountID] == nil {
			hub.accountConnections[accountID] = make(map[*Subscription]struct{})
		}
		hub.accountConnections[accountID][subscription] = struct{}{}
		if !unconfirmed {
			nextState := "online"
			if idleReconnect {
				nextState = "idle"
			}
			stateChanged := hub.presenceStates[accountID] != nextState
			hub.presenceStates[accountID] = nextState
			if stateChanged && onlineEvent != nil {
				hub.publishLocked(reconnectEvent(*onlineEvent, idleReconnect))
			}
		}
	}
	hub.mu.Unlock()
	return subscription
}

func (subscription *Subscription) BecameOnline() bool { return subscription.becameOnline }

func (hub *Hub) SubscribeAccountAt(accountID string, onlineEvent Event, at time.Time) *Subscription {
	if at.IsZero() {
		at = time.Now()
	}
	var event *Event
	if onlineEvent.Kind != "" {
		event = &onlineEvent
	}
	return hub.subscribe(accountID, event, nil, at)
}
