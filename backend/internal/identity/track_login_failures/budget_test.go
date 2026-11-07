package trackloginfailures

import (
	"context"
	"errors"
	"sync"
	"sync/atomic"
	"testing"
	"time"
)

func testBudget(t *testing.T, cfg Config) *Budget {
	t.Helper()
	b, err := New(cfg)
	if err != nil {
		t.Fatal(err)
	}
	return b
}

func TestFailureWindowStartsAtFirstFailure(t *testing.T) {
	now := time.Unix(1000, 0)
	b := testBudget(t, Config{Limit: 8, Window: 30 * time.Second, Capacity: 10, Now: func() time.Time { return now }})
	p, _, _ := b.Reserve(context.Background(), "member")
	p.Finish(false)
	now = now.Add(29 * time.Second)
	for range 8 {
		p, _, err := b.Reserve(context.Background(), "member")
		if err != nil {
			t.Fatal(err)
		}
		p.Finish(true)
	}
	now = now.Add(time.Second)
	if _, retry, err := b.Reserve(context.Background(), "member"); !errors.Is(err, ErrLimited) || retry != 29*time.Second {
		t.Fatalf("failure window was reset: %v %v", retry, err)
	}
	now = now.Add(29 * time.Second)
	p, _, err := b.Reserve(context.Background(), "member")
	if err != nil {
		t.Fatal("finite failure window did not recover", err)
	}
	p.Finish(false)
}

func TestConcurrentReservationsBoundFailureWork(t *testing.T) {
	b := testBudget(t, Config{Limit: 8, Window: 30 * time.Second, Capacity: 10})
	var admitted atomic.Int32
	start, finish := make(chan struct{}), make(chan struct{})
	ready := make(chan struct{}, 40)
	var workers sync.WaitGroup
	for range 40 {
		workers.Add(1)
		go func() {
			defer workers.Done()
			<-start
			p, _, err := b.Reserve(context.Background(), "member")
			if err == nil {
				admitted.Add(1)
				ready <- struct{}{}
				<-finish
				p.Finish(true)
			} else {
				ready <- struct{}{}
			}
		}()
	}
	close(start)
	for range 40 {
		<-ready
	}
	close(finish)
	workers.Wait()
	if admitted.Load() != 8 {
		t.Fatalf("admitted %d", admitted.Load())
	}
	if _, _, err := b.Reserve(context.Background(), "member"); !errors.Is(err, ErrLimited) {
		t.Fatal("failure limit not enforced")
	}
}

func TestSuccessDoesNotStartFailureWindowOrFillStore(t *testing.T) {
	b := testBudget(t, Config{Limit: 2, Window: time.Minute, Capacity: 1})
	for range 1000 {
		p, _, err := b.Reserve(context.Background(), "member")
		if err != nil {
			t.Fatal(err)
		}
		p.Finish(false)
	}
	p, _, err := b.Reserve(context.Background(), "different")
	if err != nil {
		t.Fatal("success-only key retained capacity", err)
	}
	p.Finish(false)
}
