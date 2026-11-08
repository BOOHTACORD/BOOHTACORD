package trackloginfailures

import (
	"context"
	"errors"
	"testing"
	"time"
)

func TestExpiredWindowKeepsInFlightAndChargesLateFailure(t *testing.T) {
	now := time.Unix(1000, 0)
	b := testBudget(t, Config{Limit: 2, Window: 30 * time.Second, Capacity: 1, Now: func() time.Time { return now }})
	first, _, _ := b.Reserve(context.Background(), "member")
	first.Finish(true)
	late, _, _ := b.Reserve(context.Background(), "member")
	now = now.Add(31 * time.Second)
	if _, _, err := b.Reserve(context.Background(), "member"); !errors.Is(err, ErrLimited) {
		t.Fatal("lost in-flight reservation")
	}
	late.Finish(true)
	late.Finish(false)
	second, _, err := b.Reserve(context.Background(), "member")
	if err != nil {
		t.Fatal(err)
	}
	second.Finish(true)
	if _, _, err := b.Reserve(context.Background(), "member"); !errors.Is(err, ErrLimited) {
		t.Fatal("late failure was forgotten")
	}
	now = now.Add(30 * time.Second)
	next, _, err := b.Reserve(context.Background(), "other")
	if err != nil {
		t.Fatal(err)
	}
	next.Finish(false)
}

func TestSaturationAndCancellationFailClosed(t *testing.T) {
	b := testBudget(t, Config{Limit: 1, Window: time.Minute, Capacity: 1})
	p, _, err := b.Reserve(context.Background(), "first")
	if err != nil {
		t.Fatal(err)
	}
	p.Finish(true)
	if _, delay, err := b.Reserve(context.Background(), "other"); !errors.Is(err, ErrSaturated) || delay <= 0 {
		t.Fatal("capacity was not enforced")
	}
	ctx, cancel := context.WithCancel(context.Background())
	cancel()
	if _, _, err := b.Reserve(ctx, "first"); !errors.Is(err, context.Canceled) {
		t.Fatal("cancelled request was admitted")
	}
	if _, err := New(Config{}); err == nil {
		t.Fatal("invalid config accepted")
	}
}
