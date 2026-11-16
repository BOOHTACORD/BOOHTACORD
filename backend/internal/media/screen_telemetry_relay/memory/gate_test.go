package memory

import (
	"errors"
	"testing"
	"time"

	relay "voice-platform/backend/internal/media/screen_telemetry_relay"
)

func TestGateRejectsOutOfOrderAndTooFrequentSamplesAndExpiresState(t *testing.T) {
	now := time.Date(2026, 11, 16, 12, 0, 0, 0, time.UTC)
	gate := NewGate(func() time.Time { return now })
	if err := gate.Accept("owner", "session", 4, 10, now); err != nil {
		t.Fatalf("first sample: %v", err)
	}
	if err := gate.Accept("owner", "session", 4, 9, now.Add(3*time.Second)); !errors.Is(err, relay.ErrStale) {
		t.Fatalf("old sequence error = %v", err)
	}
	if err := gate.Accept("owner", "session", 4, 11, now.Add(time.Second)); !errors.Is(err, relay.ErrRateLimited) {
		t.Fatalf("too frequent error = %v", err)
	}
	if err := gate.Accept("owner", "session", 4, 11, now.Add(3*time.Second)); err != nil {
		t.Fatalf("next bounded sample: %v", err)
	}
	if err := gate.Accept("owner", "session", 5, 1, now.Add(4*time.Second)); err != nil {
		t.Fatalf("new generation did not reset sequence: %v", err)
	}
	if err := gate.Accept("owner", "session", 5, 1, now.Add(20*time.Second)); err != nil {
		t.Fatalf("expired gate state did not reset: %v", err)
	}
}

func TestGateCapacityIsBounded(t *testing.T) {
	gate := NewBoundedGate(time.Now, 1)
	now := time.Now()
	if err := gate.Accept("first", "session", 1, 1, now); err != nil {
		t.Fatal(err)
	}
	if err := gate.Accept("second", "session", 1, 1, now); !errors.Is(err, relay.ErrCapacity) {
		t.Fatalf("capacity error = %v", err)
	}
}

func TestProductionGateRemovesSequenceStateAfterTTL(t *testing.T) {
	gate := NewGate(nil)
	gate.ttl = 15 * time.Millisecond
	if err := gate.Accept("owner", "session", 1, 1, time.Now()); err != nil {
		t.Fatal(err)
	}
	time.Sleep(40 * time.Millisecond)
	gate.mu.Lock()
	defer gate.mu.Unlock()
	if len(gate.entries) != 0 {
		t.Fatalf("expired anti-replay state remains in memory: %d", len(gate.entries))
	}
}
