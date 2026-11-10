package coordinateroster

import (
	"context"
	"sync/atomic"
	"testing"
	"time"

	roster "voice-platform/backend/internal/voice/list_connected_participants"
)

type countingLister struct {
	active, peak atomic.Int32
	started      chan struct{}
	release      chan struct{}
}

func (l *countingLister) List(ctx context.Context, account string) (roster.Result, error) {
	count := l.active.Add(1)
	for old := l.peak.Load(); count > old && !l.peak.CompareAndSwap(old, count); old = l.peak.Load() {
	}
	l.started <- struct{}{}
	defer l.active.Add(-1)
	select {
	case <-l.release:
		return roster.Result{Channels: []roster.ChannelRoster{{ChannelID: account}}}, nil
	case <-ctx.Done():
		return roster.Result{}, ctx.Err()
	}
}

func TestWorkerConcurrencyIsBounded(t *testing.T) {
	lister := &countingLister{started: make(chan struct{}, 8), release: make(chan struct{})}
	c, _, _ := fixture(t, lister)
	for _, id := range []string{accountA, accountB, "33333333-3333-4333-8333-333333333333", "44444444-4444-4444-8444-444444444444"} {
		if _, err := c.Subscribe(id); err != nil {
			t.Fatal(err)
		}
	}
	for i := 0; i < 2; i++ {
		select {
		case <-lister.started:
		case <-time.After(time.Second):
			t.Fatal("worker did not start")
		}
	}
	select {
	case <-lister.started:
		t.Fatal("worker limit exceeded")
	case <-time.After(50 * time.Millisecond):
	}
	close(lister.release)
	if lister.peak.Load() > 2 {
		t.Fatalf("peak workers: %d", lister.peak.Load())
	}
}
