package eventhub

import "context"

func (hub *Hub) Publish(event Event) {
	ctx, cancel := backgroundWriteContext()
	defer cancel()
	_ = hub.PublishContext(ctx, event)
}

// PublishContext reports journal failure to the committed-operation observer.
func (hub *Hub) PublishContext(ctx context.Context, event Event) error {
	hub.publishMu.Lock()
	defer hub.publishMu.Unlock()
	var err error
	event, err = hub.persist(ctx, event, nil, false)
	if err != nil {
		return err
	}
	hub.mu.Lock()
	defer hub.mu.Unlock()
	hub.publishLocked(event)
	return nil
}

func (hub *Hub) publishLocked(event Event) {
	for subscription := range hub.subscribers {
		if !subscription.dropped {
			hub.deliverLocked(subscription, event)
		}
	}
}

func (hub *Hub) deliverLocked(subscription *Subscription, event Event) {
	if capability := requiredCapability(event.Kind); capability != "" {
		if _, supported := subscription.capabilities[capability]; !supported {
			return
		}
	}
	select {
	case subscription.events <- event:
	default:
		subscription.dropped = true
		subscription.overflowed <- struct{}{}
	}
}

func requiredCapability(kind string) string {
	switch kind {
	case "notification.queued", "notification.preferences_changed":
		return "notifications_v1"
	case "message.reactions_updated", "message.pins_updated", "direct_message.reactions_updated":
		return "message_social_v1"
	case "role.permissions.updated", "auth.permissions.invalidated":
		return "role_permissions_v1"
	case "screen_preview.updated", "screen_preview.invalidated":
		return "screen_previews_v1"
	case "screen_viewers.changed":
		return "screen_viewers_v1"
	default:
		return ""
	}
}
