package coordinateroster

import (
	"context"
	"testing"
	"time"
)

type refreshObserver chan bool

func (o refreshObserver) ObserveRosterWSRefresh(success bool) { o <- success }

func TestObserverReportsOnlyCompletedRefreshes(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	lister := &fakeLister{}
	observer := make(refreshObserver, 4)
	c, err := New(Config{Workers: 1, MaxAccounts: 1, MaxSubscribers: 1, MaxSnapshotBytes: 4096, PollInterval: time.Hour, ReadTimeout: time.Second}, lister, nil, observer)
	if err != nil {
		t.Fatal(err)
	}
	go c.Run(ctx)
	sub, err := c.Subscribe(accountA)
	if err != nil {
		t.Fatal(err)
	}
	defer sub.Close()
	receive(t, sub)
	select {
	case ok := <-observer:
		if !ok {
			t.Fatal("successful refresh marked failed")
		}
	case <-time.After(time.Second):
		t.Fatal("missing refresh")
	}
	lister.mode.Store(2)
	c.Invalidate()
	receive(t, sub)
	select {
	case ok := <-observer:
		if ok {
			t.Fatal("failed refresh marked successful")
		}
	case <-time.After(time.Second):
		t.Fatal("missing failed refresh")
	}
}
