package eventhub

func (subscription *Subscription) AcknowledgeOverflow() {
	subscription.hub.mu.Lock()
	defer subscription.hub.mu.Unlock()
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
			return
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

// retainCriticalLocked returns false when a durable revoke must be retried.
// At most one original queue's worth of revocations is retained per socket.
func (subscription *Subscription) retainCriticalLocked(event Event) bool {
	if event.Kind != "voice.lease_revoked" {
		return true
	}
	for _, previous := range subscription.critical {
		if previous.EventID == event.EventID {
			return true
		}
	}
	if len(subscription.critical) >= cap(subscription.events) {
		return false
	}
	subscription.critical = append(subscription.critical, event)
	return true
}
