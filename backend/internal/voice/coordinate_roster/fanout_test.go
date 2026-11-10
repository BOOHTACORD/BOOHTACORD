package coordinateroster

import (
	"context"
	"testing"
	"time"
)

func TestConcurrentSubscribersShareFreshAccountRead(t *testing.T) {
	lister := &blockingLister{started: make(chan struct{}), release: make(chan struct{})}
	c, err := New(Config{Workers: 2, MaxAccounts: 1, MaxSubscribers: 100, PollInterval: time.Hour, ReadTimeout: 2 * time.Second, MaxSnapshotBytes: 4096}, lister, nil)
	if err != nil {
		t.Fatal(err)
	}
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	go c.Run(ctx)
	first, err := c.Subscribe(accountA)
	if err != nil {
		t.Fatal(err)
	}
	defer first.Close()
	select {
	case <-lister.started:
	case <-time.After(time.Second):
		t.Fatal("read not started")
	}
	subs := []*Subscription{first}
	for i := 1; i < 100; i++ {
		sub, err := c.Subscribe(accountA)
		if err != nil {
			t.Fatal(err)
		}
		subs = append(subs, sub)
		defer sub.Close()
	}
	close(lister.release)
	for _, sub := range subs {
		state := receive(t, sub)
		if state.Unavailable || state.Revision != 1 {
			t.Fatalf("initial state: %+v", state)
		}
	}
	if calls := lister.calls.Load(); calls != 2 {
		t.Fatalf("reads = %d, want discarded initial and one shared refresh", calls)
	}
}
