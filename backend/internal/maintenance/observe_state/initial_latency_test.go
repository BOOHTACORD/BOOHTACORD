package observestate

import (
	"context"
	"sync/atomic"
	"testing"
	"time"
)

func TestLateSubscriberGetsFreshReadWithoutWaitingForReconciliation(t *testing.T) {
	var active atomic.Bool
	observer := New(readerFunc(func(context.Context) (bool, error) { return active.Load(), nil }), time.Hour, time.Second)
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	go observer.Run(ctx)
	first := observer.Subscribe()
	defer first.Close()
	if initial := receive(t, first.Events()); !initial.Known || initial.Active {
		t.Fatalf("first state = %+v", initial)
	}
	active.Store(true)
	late := observer.Subscribe()
	defer late.Close()
	select {
	case state := <-late.Events():
		if !state.Known || !state.Active {
			t.Fatalf("late state = %+v", state)
		}
	case <-time.After(500 * time.Millisecond):
		t.Fatal("late subscriber waited for the periodic reconciliation interval")
	}
}
