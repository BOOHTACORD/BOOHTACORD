package centralexport

import (
	"context"
	"testing"
	"time"
	identity "voice-platform/backend/internal/observability/installation"
)

func TestDisabledExportCannotQueueAndOverflowDoesNotBlock(t *testing.T) {
	i, _ := identity.New()
	r := New(i, nil, nil)
	if r.Enqueue("traces", []byte("anything")) {
		t.Fatal("disabled egress accepted")
	}
	i.Mode = "central"
	i.Endpoint = "https://example.test"
	i.Credential = "test"
	r.replace(i)
	start := time.Now()
	accepted := 0
	for n := 0; n < 1000; n++ {
		if r.Enqueue("traces", make([]byte, 512*1024)) {
			accepted++
		}
	}
	if accepted > 32 || time.Since(start) > time.Second {
		t.Fatal("unbounded or blocking queue")
	}
	r.Disable(context.Background())
	if r.Enqueue("traces", []byte("x")) {
		t.Fatal("disabled egress restarted")
	}
	if r.Snapshot().Queued != 0 {
		t.Fatal("disable retained pending queue")
	}
}
