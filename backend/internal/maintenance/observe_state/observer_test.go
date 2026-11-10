package observestate

import (
	"context"
	"errors"
	"sync/atomic"
	"testing"
	"time"
)

type readerFunc func(context.Context) (bool, error)

func (f readerFunc) Active(ctx context.Context) (bool, error) { return f(ctx) }

func receive(t *testing.T, events <-chan State) State {
	t.Helper()
	select {
	case state := <-events:
		return state
	case <-time.After(time.Second):
		t.Fatal("timed out waiting for maintenance state")
		return State{}
	}
}

func TestObserverInitialChangeUnavailableAndRecovery(t *testing.T) {
	var mode atomic.Int32
	observer := New(readerFunc(func(context.Context) (bool, error) {
		switch mode.Load() {
		case 1:
			return true, nil
		case 2:
			return false, errors.New("private database error")
		default:
			return false, nil
		}
	}), 10*time.Millisecond, time.Second)
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	go observer.Run(ctx)
	sub := observer.Subscribe()
	defer sub.Close()
	initial := receive(t, sub.Events())
	if !initial.Known || initial.Active || initial.Generation == "" || initial.Revision != 1 {
		t.Fatalf("initial = %+v", initial)
	}
	mode.Store(1)
	observer.RequestRefresh()
	changed := receive(t, sub.Events())
	if !changed.Known || !changed.Active || changed.Revision != 2 || changed.Generation != initial.Generation {
		t.Fatalf("changed = %+v", changed)
	}
	mode.Store(2)
	observer.RequestRefresh()
	unavailable := receive(t, sub.Events())
	if unavailable.Known || unavailable.Revision != 3 {
		t.Fatalf("unavailable = %+v", unavailable)
	}
	mode.Store(0)
	observer.RequestRefresh()
	recovered := receive(t, sub.Events())
	if !recovered.Known || recovered.Active || recovered.Revision != 4 {
		t.Fatalf("recovered = %+v", recovered)
	}
}

func TestObserverDoesNotReadWithoutSubscribers(t *testing.T) {
	var calls atomic.Int32
	observer := New(readerFunc(func(context.Context) (bool, error) {
		calls.Add(1)
		return false, nil
	}), time.Millisecond, time.Second)
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	go observer.Run(ctx)
	observer.RequestRefresh()
	time.Sleep(30 * time.Millisecond)
	if calls.Load() != 0 {
		t.Fatalf("reads without subscribers = %d", calls.Load())
	}
}

func TestObserverShutdownClosesSubscriptions(t *testing.T) {
	observer := New(readerFunc(func(context.Context) (bool, error) { return false, nil }), time.Hour, time.Second)
	ctx, cancel := context.WithCancel(context.Background())
	done := make(chan struct{})
	go func() { observer.Run(ctx); close(done) }()
	sub := observer.Subscribe()
	receive(t, sub.Events())
	cancel()
	select {
	case <-done:
	case <-time.After(time.Second):
		t.Fatal("observer did not stop")
	}
	if _, open := <-sub.Events(); open {
		t.Fatal("subscription remained open after shutdown")
	}
	late := observer.Subscribe()
	if _, open := <-late.Events(); open {
		t.Fatal("subscription after shutdown remained open")
	}
	sub.Close()
	late.Close()
}

func TestExpiredReadIsUnavailableEvenIfReaderReturnsSuccess(t *testing.T) {
	observer := New(readerFunc(func(ctx context.Context) (bool, error) {
		<-ctx.Done()
		return false, nil
	}), time.Hour, 10*time.Millisecond)
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	go observer.Run(ctx)
	sub := observer.Subscribe()
	defer sub.Close()
	if state := receive(t, sub.Events()); state.Known {
		t.Fatalf("expired read was treated as authoritative: %+v", state)
	}
}
