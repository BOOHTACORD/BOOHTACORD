package observestate

import (
	"context"
	"sync/atomic"
	"testing"
	"time"
)

func TestPacedSubscribersShareReads(t *testing.T) {
	var calls atomic.Int32
	observer := New(readerFunc(func(context.Context) (bool, error) {
		calls.Add(1)
		return false, nil
	}), time.Hour, time.Second)
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	go observer.Run(ctx)
	ticker := time.NewTicker(time.Millisecond)
	defer ticker.Stop()
	deadline := time.NewTimer(100 * time.Millisecond)
	defer deadline.Stop()
	var subscribers []*Subscription
	for {
		select {
		case <-ticker.C:
			subscribers = append(subscribers, observer.Subscribe())
		case <-deadline.C:
			goto received
		}
	}
received:
	for _, sub := range subscribers {
		if state := receive(t, sub.Events()); !state.Known {
			t.Fatal("subscriber did not receive authoritative state")
		}
		sub.Close()
	}
	if len(subscribers) < 5 {
		t.Fatal("insufficient subscriber activity to test coalescing")
	}
	if got := calls.Load(); got > 35 {
		t.Fatalf("paced subscribers triggered %d reads; expected bounded coalescing", got)
	}
}
