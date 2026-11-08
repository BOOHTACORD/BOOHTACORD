package observestate

import (
	"context"
	"sync/atomic"
	"testing"
	"time"
)

func TestSubscriberBurstSharesBoundedReads(t *testing.T) {
	var calls atomic.Int32
	started := make(chan struct{})
	release := make(chan struct{})
	observer := New(readerFunc(func(ctx context.Context) (bool, error) {
		if calls.Add(1) == 1 {
			close(started)
			select {
			case <-release:
			case <-ctx.Done():
				return false, ctx.Err()
			}
		}
		return false, nil
	}), time.Hour, time.Second)
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	go observer.Run(ctx)
	first := observer.Subscribe()
	defer first.Close()
	select {
	case <-started:
	case <-time.After(time.Second):
		t.Fatal("initial read did not start")
	}
	var subscriptions []*Subscription
	for i := 0; i < 20; i++ {
		subscriptions = append(subscriptions, observer.Subscribe())
	}
	close(release)
	receive(t, first.Events())
	for _, sub := range subscriptions {
		if state := receive(t, sub.Events()); !state.Known {
			t.Fatalf("initial state = %+v", state)
		}
		sub.Close()
	}
	if got := calls.Load(); got != 2 {
		t.Fatalf("subscriber burst used %d reads, want two shared reads", got)
	}
}

func TestShutdownDiscardsQueuedState(t *testing.T) {
	observer := New(readerFunc(func(context.Context) (bool, error) { return true, nil }), time.Hour, time.Second)
	ctx, cancel := context.WithCancel(context.Background())
	done := make(chan struct{})
	go func() { observer.Run(ctx); close(done) }()
	sub := observer.Subscribe()
	deadline := time.Now().Add(time.Second)
	for len(sub.Events()) == 0 && time.Now().Before(deadline) {
		time.Sleep(time.Millisecond)
	}
	if len(sub.Events()) == 0 {
		cancel()
		t.Fatal("initial state was not queued")
	}
	cancel()
	<-done
	if state, open := <-sub.Events(); open {
		t.Fatalf("queued state survived shutdown: %+v", state)
	}
}
