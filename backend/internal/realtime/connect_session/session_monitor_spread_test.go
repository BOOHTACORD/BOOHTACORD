package connectsession

import (
	"crypto/sha256"
	"fmt"
	"testing"
	"time"
)

func TestSessionMonitorFirstCheckSpreadsWithinExistingInterval(t *testing.T) {
	interval := 1500 * time.Millisecond
	unique := make(map[time.Duration]bool)
	for i := 0; i < 100; i++ {
		digest := sha256.Sum256([]byte(fmt.Sprintf("synthetic-session-%d", i)))
		delay := sessionMonitorFirstDelay(digest, interval)
		if delay < 0 || delay >= interval {
			t.Fatalf("first check exceeds existing interval: %s", delay)
		}
		if delay != sessionMonitorFirstDelay(digest, interval) {
			t.Fatal("first-check schedule changed for the same session")
		}
		unique[delay] = true
	}
	if len(unique) < 95 {
		t.Fatalf("first checks are not sufficiently spread: %d", len(unique))
	}
}

func TestSessionMonitorUnknownDigestPreservesFirstInterval(t *testing.T) {
	if got := sessionMonitorFirstDelay([32]byte{}, time.Second); got != time.Second {
		t.Fatalf("unknown digest first check = %s", got)
	}
}
