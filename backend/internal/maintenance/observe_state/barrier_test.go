package observestate

import (
	"context"
	"sync/atomic"
	"testing"
	"time"
)

func TestLateSubscriberWaitsForReadStartedAfterSubscription(t *testing.T) {
	started := make(chan int32, 2)
	release := make(chan struct{})
	var calls atomic.Int32
	observer := New(readerFunc(func(ctx context.Context) (bool, error) {
		n := calls.Add(1)
		started <- n
		if n == 1 {
			select {
			case <-release:
			case <-ctx.Done():
				return false, ctx.Err()
			}
		}
		return n > 1, nil
	}), 10*time.Millisecond, time.Second)
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	go observer.Run(ctx)
	first := observer.Subscribe()
	defer first.Close()
	<-started
	late := observer.Subscribe()
	defer late.Close()
	close(release)
	state := receive(t, late.Events())
	if !state.Known || !state.Active || calls.Load() < 2 {
		t.Fatalf("late initial = %+v after %d reads", state, calls.Load())
	}
}

func TestSlowSubscriberReceivesLatestState(t *testing.T) {
	var active atomic.Bool
	reads := make(chan struct{}, 4)
	observer := New(readerFunc(func(context.Context) (bool, error) {
		reads <- struct{}{}
		return active.Load(), nil
	}), 10*time.Millisecond, time.Second)
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	go observer.Run(ctx)
	sub := observer.Subscribe()
	defer sub.Close()
	<-reads
	// Wait for the first state to be delivered without consuming it.
	initialDeadline := time.Now().Add(time.Second)
	for len(sub.Events()) == 0 && time.Now().Before(initialDeadline) {
		time.Sleep(time.Millisecond)
	}
	if len(sub.Events()) == 0 {
		t.Fatal("initial state was not delivered")
	}
	active.Store(true)
	observer.RequestRefresh()
	<-reads
	deadline := time.Now().Add(time.Second)
	for time.Now().Before(deadline) {
		state := receive(t, sub.Events())
		if state.Active && state.Known && state.Revision == 2 {
			return
		}
	}
	t.Fatal("latest state was not delivered")
}
