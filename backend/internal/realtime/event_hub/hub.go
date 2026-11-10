package eventhub

import (
	"sync"
	"time"

	"github.com/google/uuid"
	causal "voice-platform/backend/internal/observability/causal_reference"
)

type Event struct {
	EventID    string             `json:"event_id"`
	Kind       string             `json:"kind"`
	OccurredAt time.Time          `json:"occurred_at"`
	Payload    map[string]any     `json:"payload"`
	Cause      causal.Cause       `json:"-"`
	Telemetry  *TelemetryEnvelope `json:"telemetry,omitempty"`
}

type Hub struct {
	mu           sync.Mutex
	publishMu    sync.Mutex
	queueSize    int
	subscribers  map[*Subscription]struct{}
	connections  map[string]int
	journal      Journal
	bootEpoch    string
	broken       bool
	telemetryKey string
}

type Subscription struct {
	hub          *Hub
	accountID    string
	becameOnline bool
	events       chan Event
	overflowed   chan struct{}
	critical     []Event
	dropped      bool
	capabilities map[string]struct{}
	once         sync.Once
}

func New(queueSize int) *Hub {
	if queueSize < 1 {
		queueSize = 1
	}
	return &Hub{queueSize: queueSize, subscribers: make(map[*Subscription]struct{}), connections: make(map[string]int), bootEpoch: uuid.NewString()}
}

func (hub *Hub) Subscribe(accountIDs ...string) *Subscription {
	accountID := ""
	if len(accountIDs) > 0 {
		accountID = accountIDs[0]
	}
	return hub.subscribe(accountID, nil, nil)
}

func (hub *Hub) SubscribeAccount(accountID string, onlineEvent Event) *Subscription {
	return hub.subscribe(accountID, &onlineEvent, nil)
}

func (hub *Hub) subscribe(accountID string, onlineEvent *Event, capabilities map[string]struct{}) *Subscription {
	subscription := &Subscription{hub: hub, accountID: accountID, capabilities: capabilities, events: make(chan Event, hub.queueSize), overflowed: make(chan struct{}, 1)}
	hub.mu.Lock()
	hub.subscribers[subscription] = struct{}{}
	if hub.broken {
		subscription.dropped = true
		subscription.overflowed <- struct{}{}
	}
	if accountID != "" {
		subscription.becameOnline = hub.connections[accountID] == 0
		hub.connections[accountID]++
		if subscription.becameOnline && onlineEvent != nil {
			hub.publishLocked(*onlineEvent)
		}
	}
	hub.mu.Unlock()
	return subscription
}

func (subscription *Subscription) BecameOnline() bool { return subscription.becameOnline }

func (subscription *Subscription) Events() <-chan Event        { return subscription.events }
func (subscription *Subscription) Overflowed() <-chan struct{} { return subscription.overflowed }

func (subscription *Subscription) Close(offlineEvents ...Event) bool {
	becameOffline := false
	subscription.once.Do(func() {
		subscription.hub.mu.Lock()
		delete(subscription.hub.subscribers, subscription)
		if subscription.accountID != "" {
			if subscription.hub.connections[subscription.accountID] <= 1 {
				delete(subscription.hub.connections, subscription.accountID)
				becameOffline = true
			} else {
				subscription.hub.connections[subscription.accountID]--
			}
		}
		if becameOffline && len(offlineEvents) > 0 {
			subscription.hub.publishLocked(offlineEvents[0])
		}
		subscription.hub.mu.Unlock()
	})
	return becameOffline
}
