package memory

import (
	"sync"
	"time"

	relay "voice-platform/backend/internal/media/screen_telemetry_relay"
)

const (
	GateTTL               = 15 * time.Second
	MinimumSampleInterval = 2500 * time.Millisecond
	MaxGateEntries        = 4096
)

type gateEntry struct {
	mediaSessionID string
	generation     uint64
	sequence       uint64
	lastAccepted   time.Time
	timer          *time.Timer
}

// Gate retains only bounded anti-replay/rate-limit state; telemetry samples
// themselves are never kept here.
type Gate struct {
	mu       sync.Mutex
	entries  map[string]*gateEntry
	now      func() time.Time
	ttl      time.Duration
	interval time.Duration
	capacity int
	timers   bool
}

func NewGate(now func() time.Time) *Gate {
	if now == nil {
		return newBoundedGate(time.Now, MaxGateEntries, true)
	}
	return newBoundedGate(now, MaxGateEntries, false)
}

func NewBoundedGate(now func() time.Time, capacity int) *Gate {
	if now == nil {
		now = time.Now
	}
	return newBoundedGate(now, capacity, false)
}

func newBoundedGate(now func() time.Time, capacity int, timers bool) *Gate {
	if capacity < 1 {
		capacity = 1
	}
	return &Gate{entries: make(map[string]*gateEntry), now: now, ttl: GateTTL, interval: MinimumSampleInterval, capacity: capacity, timers: timers}
}

func (gate *Gate) Accept(ownerLeaseID, mediaSessionID string, generation, sequence uint64, receivedAt time.Time) error {
	if ownerLeaseID == "" || mediaSessionID == "" || generation == 0 || sequence == 0 {
		return relay.ErrInvalid
	}
	if receivedAt.IsZero() {
		receivedAt = gate.now()
	}
	gate.mu.Lock()
	defer gate.mu.Unlock()
	for key, current := range gate.entries {
		if receivedAt.Sub(current.lastAccepted) >= gate.ttl {
			if current.timer != nil {
				current.timer.Stop()
			}
			delete(gate.entries, key)
		}
	}
	current, exists := gate.entries[ownerLeaseID]
	if exists && receivedAt.Sub(current.lastAccepted) < 0 {
		return relay.ErrStale
	}
	samePublication := exists && current.mediaSessionID == mediaSessionID && current.generation == generation
	if samePublication {
		if sequence <= current.sequence {
			return relay.ErrStale
		}
		if receivedAt.Sub(current.lastAccepted) < gate.interval {
			return relay.ErrRateLimited
		}
	} else if !exists && len(gate.entries) >= gate.capacity {
		return relay.ErrCapacity
	}
	if current != nil && current.timer != nil {
		current.timer.Stop()
	}
	entry := &gateEntry{mediaSessionID: mediaSessionID, generation: generation, sequence: sequence, lastAccepted: receivedAt}
	gate.entries[ownerLeaseID] = entry
	if gate.timers {
		entry.timer = time.AfterFunc(gate.ttl, func() { gate.expire(ownerLeaseID, entry) })
	}
	return nil
}

func (gate *Gate) expire(ownerLeaseID string, expected *gateEntry) {
	gate.mu.Lock()
	defer gate.mu.Unlock()
	current := gate.entries[ownerLeaseID]
	if current != expected {
		return
	}
	remaining := gate.ttl - gate.now().Sub(current.lastAccepted)
	if remaining > 0 {
		current.timer = time.AfterFunc(remaining, func() { gate.expire(ownerLeaseID, expected) })
		return
	}
	delete(gate.entries, ownerLeaseID)
}
