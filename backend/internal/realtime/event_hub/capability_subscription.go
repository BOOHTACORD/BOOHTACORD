package eventhub

import "time"

func (subscription *Subscription) AllowsKind(kind string) bool {
	capability := requiredCapability(kind)
	if capability == "" {
		return true
	}
	_, supported := subscription.capabilities[capability]
	return supported
}

func (hub *Hub) SubscribeAccountWithCapabilities(accountID string, onlineEvent Event, capabilities []string) *Subscription {
	set := make(map[string]struct{}, len(capabilities))
	for _, capability := range capabilities {
		if capability != "" {
			set[capability] = struct{}{}
		}
	}
	if onlineEvent.Kind == "" {
		return hub.subscribe(accountID, nil, set, time.Now())
	}
	return hub.subscribe(accountID, &onlineEvent, set, time.Now())
}
