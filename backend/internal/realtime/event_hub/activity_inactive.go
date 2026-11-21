package eventhub

import "time"

// ReportInactive records the beginning of a confirmed absence only when the
// socket has no earlier activity evidence. It never produces an online event.
func (hub *Hub) ReportInactive(subscription *Subscription, at time.Time) {
	if hub == nil || subscription == nil || subscription.accountID == "" {
		return
	}
	if at.IsZero() {
		at = time.Now()
	}
	guard := hub.activityGuard(subscription.accountID)
	guard.Lock()
	defer guard.Unlock()
	hub.mu.Lock()
	defer hub.mu.Unlock()
	if _, connected := hub.accountConnections[subscription.accountID][subscription]; !connected {
		return
	}
	if _, capable := subscription.capabilities["confirmed_activity_v1"]; !capable {
		return
	}
	if subscription.lastActivity.IsZero() {
		subscription.lastActivity = at
		subscription.inactivityOnly = true
	}
}
