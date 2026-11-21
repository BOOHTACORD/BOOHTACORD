package eventhub

import "time"

func (subscription *Subscription) Close(offlineEvents ...Event) bool {
	becameOffline := false
	subscription.once.Do(func() {
		guard := subscription.hub.activityGuard(subscription.accountID)
		guard.Lock()
		defer guard.Unlock()
		subscription.hub.mu.Lock()
		delete(subscription.hub.subscribers, subscription)
		if subscription.accountID != "" {
			previous := subscription.hub.presenceStates[subscription.accountID]
			if subscription.hub.connections[subscription.accountID] <= 1 {
				subscription.hub.rememberDisconnected(subscription.accountID, reconnectEntry{at: subscription.lastActivity, inactivityOnly: subscription.inactivityOnly, idle: previous == "idle"})
				delete(subscription.hub.connections, subscription.accountID)
				delete(subscription.hub.accountConnections, subscription.accountID)
				delete(subscription.hub.presenceStates, subscription.accountID)
				becameOffline = true
			} else {
				subscription.hub.connections[subscription.accountID]--
				delete(subscription.hub.accountConnections[subscription.accountID], subscription)
				if previous == "online" && allPresenceIdle(subscription.hub.accountConnections[subscription.accountID], time.Now().Add(-DefaultIdleAfter)) {
					subscription.hub.presenceStates[subscription.accountID] = "idle"
					subscription.hub.publishLocked(presenceChanged(subscription.accountID, "idle", time.Now()))
				}
			}
		}
		if becameOffline && len(offlineEvents) > 0 {
			subscription.hub.publishLocked(offlineEvents[0])
		}
		subscription.hub.mu.Unlock()
	})
	return becameOffline
}
