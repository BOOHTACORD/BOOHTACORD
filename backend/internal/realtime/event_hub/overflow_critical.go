package eventhub

func (subscription *Subscription) AcknowledgeOverflow() bool {
	subscription.hub.mu.Lock()
	defer subscription.hub.mu.Unlock()
	if subscription.closeRequired {
		return false
	}
	for {
		select {
		case <-subscription.events:
		default:
			for _, event := range subscription.critical {
				subscription.events <- event
			}
			subscription.critical = nil
			subscription.dropped = false
			select {
			case <-subscription.overflowed:
			default:
			}
			return true
		}
	}
}

// captureCriticalLocked runs under the hub lock, after ordinary delivery has
// overflowed. The writer may consume concurrently, but no publisher can add.
func (subscription *Subscription) captureCriticalLocked() {
	for {
		select {
		case event := <-subscription.events:
			subscription.retainCriticalLocked(event)
		default:
			return
		}
	}
}

// Retention is bounded by the original queue capacity. A transient security
// hint that cannot be retained requires the socket to close and resynchronize.
func (subscription *Subscription) retainCriticalLocked(event Event) bool {
	switch event.Kind {
	case "voice.lease_revoked", "session.state_changed", "auth.permissions.invalidated", "role.permissions.updated":
	default:
		return true
	}
	for _, previous := range subscription.critical {
		if previous.Kind == event.Kind && previous.EventID == event.EventID {
			return true
		}
	}
	if len(subscription.critical) >= cap(subscription.events) {
		if event.Kind != "voice.lease_revoked" {
			subscription.closeRequired = true
		}
		return false
	}
	subscription.critical = append(subscription.critical, event)
	return true
}
