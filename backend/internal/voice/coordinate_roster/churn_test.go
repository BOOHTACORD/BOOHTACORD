package coordinateroster

import (
	"context"
	"sync"
	"testing"
	"time"
)

func TestSubscriberChurnCannotBlockAdmissionOrLoseWaitingWork(t *testing.T) {
	lister := &blockingLister{started: make(chan struct{}), release: make(chan struct{})}
	c, err := New(Config{Workers: 1, MaxAccounts: 1, MaxSubscribers: 1, PollInterval: time.Hour, ReadTimeout: 5 * time.Second, MaxSnapshotBytes: 4096}, lister, nil)
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
	<-lister.started
	var once sync.Once
	release := func() { once.Do(func() { close(lister.release) }) }
	defer release()
	first.Close()
	second, err := c.Subscribe(accountB)
	if err != nil {
		t.Fatal(err)
	}
	second.Close()
	result := make(chan *Subscription, 1)
	go func() { sub, _ := c.Subscribe("33333333-3333-4333-8333-333333333333"); result <- sub }()
	select {
	case sub := <-result:
		if sub == nil {
			t.Fatal("waiting subscriber rejected")
		}
		release()
		receive(t, sub)
		sub.Close()
	case <-time.After(250 * time.Millisecond):
		t.Fatal("full queue blocked subscriber admission")
	}
}
