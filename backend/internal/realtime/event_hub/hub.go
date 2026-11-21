package eventhub

import (
	"sync"
	"time"

	"github.com/google/uuid"
	causal "voice-platform/backend/internal/observability/causal_reference"
)

type Event struct {
	EventID      string             `json:"event_id"`
	Kind         string             `json:"kind"`
	OccurredAt   time.Time          `json:"occurred_at"`
	Payload      map[string]any     `json:"payload"`
	Cause        causal.Cause       `json:"-"`
	Telemetry    *TelemetryEnvelope `json:"telemetry,omitempty"`
	TransientKey string             `json:"-"`
}

type Hub struct {
	mu                 sync.Mutex
	activityGuards     [64]sync.Mutex
	publishMu          sync.Mutex
	queueSize          int
	subscribers        map[*Subscription]struct{}
	connections        map[string]int
	accountConnections map[string]map[*Subscription]struct{}
	presenceStates     map[string]string
	reconnectHistory   map[string]reconnectEntry
	journal            Journal
	bootEpoch          string
	broken             bool
	telemetryKey       string
}

type Subscription struct {
	hub            *Hub
	accountID      string
	lastActivity   time.Time
	inactivityOnly bool
	initiallyIdle  bool
	connectedAt    time.Time
	becameOnline   bool
	events         chan Event
	overflowed     chan struct{}
	critical       []Event
	dropped        bool
	closeRequired  bool
	capabilities   map[string]struct{}
	once           sync.Once
}

func New(queueSize int) *Hub {
	if queueSize < 1 {
		queueSize = 1
	}
	return &Hub{queueSize: queueSize, subscribers: make(map[*Subscription]struct{}), connections: make(map[string]int), accountConnections: make(map[string]map[*Subscription]struct{}), presenceStates: make(map[string]string), bootEpoch: uuid.NewString()}
}

func (subscription *Subscription) Events() <-chan Event        { return subscription.events }
func (subscription *Subscription) Overflowed() <-chan struct{} { return subscription.overflowed }
