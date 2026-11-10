package coordinateroster

import (
	"testing"
	"time"
)

func TestSubscriberBudgetAlsoBoundsMultipleSessionsOfOneAccount(t *testing.T) {
	c, err := New(Config{Workers: 1, MaxAccounts: 1, MaxSubscribers: 2, PollInterval: time.Hour, ReadTimeout: time.Second, MaxSnapshotBytes: 4096}, &fakeLister{}, nil)
	if err != nil {
		t.Fatal(err)
	}
	first, err := c.Subscribe(accountA)
	if err != nil {
		t.Fatal(err)
	}
	second, err := c.Subscribe(accountA)
	if err != nil {
		t.Fatal(err)
	}
	if _, err := c.Subscribe(accountA); err == nil {
		t.Fatal("subscriber budget exceeded")
	}
	first.Close()
	if third, err := c.Subscribe(accountA); err != nil {
		t.Fatal(err)
	} else {
		third.Close()
	}
	second.Close()
}
