package admitlogin

import (
	"context"
	"errors"
	"sync"
	"sync/atomic"
	"testing"
	"time"
)

func testBudget(t *testing.T, limit, capacity int, now func() time.Time) *Budget {
	t.Helper()
	budget, err := New(Config{Limit: limit, Window: 30 * time.Second, MaxAccounts: capacity, Now: now})
	if err != nil {
		t.Fatal(err)
	}
	return budget
}

func TestAtomicReservationCannotSpendOneSlotTwice(t *testing.T) {
	budget := testBudget(t, 8, 16, time.Now)
	var admitted atomic.Int32
	start, finish := make(chan struct{}), make(chan struct{})
	attempts := make(chan struct{}, 40)
	var workers sync.WaitGroup
	for range 40 {
		workers.Add(1)
		go func() {
			defer workers.Done()
			<-start
			permit, _, err := budget.Reserve(context.Background(), "synthetic-member")
			if err == nil {
				admitted.Add(1)
				attempts <- struct{}{}
				<-finish
				permit.Complete(Invalid)
			} else if !errors.Is(err, ErrLimited) {
				t.Error("unexpected admission error")
			}
			if err != nil {
				attempts <- struct{}{}
			}
		}()
	}
	close(start)
	// Wait for all attempts to reserve or reject without releasing the permits.
	for range 40 {
		<-attempts
	}
	close(finish)
	workers.Wait()
	if admitted.Load() != 8 {
		t.Fatalf("admitted=%d want 8", admitted.Load())
	}
	if budget.Stats().InFlight != 0 {
		t.Fatal("leaked reservation")
	}
}

func TestWindowRecoveryCannotBeExtendedByRejectedTraffic(t *testing.T) {
	now := time.Unix(1000, 0)
	budget := testBudget(t, 1, 2, func() time.Time { return now })
	permit, _, err := budget.Reserve(context.Background(), "synthetic-member")
	if err != nil {
		t.Fatal(err)
	}
	permit.Complete(Invalid)
	permit.Complete(NotStarted)
	now = now.Add(29 * time.Second)
	if _, retry, err := budget.Reserve(context.Background(), "synthetic-member"); !errors.Is(err, ErrLimited) || retry != time.Second {
		t.Fatal("denial must retain original deadline")
	}
	now = now.Add(time.Second)
	permit, _, err = budget.Reserve(context.Background(), "synthetic-member")
	if err != nil {
		t.Fatal("quiet window must recover without unlocking account")
	}
	permit.Complete(Success)
}

func TestExpiryDoesNotForgetRunningReservation(t *testing.T) {
	now := time.Unix(1000, 0)
	budget := testBudget(t, 1, 1, func() time.Time { return now })
	permit, _, _ := budget.Reserve(context.Background(), "synthetic-member")
	now = now.Add(time.Minute)
	if _, _, err := budget.Reserve(context.Background(), "other-member"); !errors.Is(err, ErrSaturated) {
		t.Fatal("must retain running old budget")
	}
	if _, _, err := budget.Reserve(context.Background(), "synthetic-member"); !errors.Is(err, ErrLimited) {
		t.Fatal("must retain running reservation across expiry")
	}
	permit.Complete(Cancelled)
	next, _, err := budget.Reserve(context.Background(), "other-member")
	if err != nil {
		t.Fatal("completed expired budget must free capacity")
	}
	next.Complete(Invalid)
}

func TestSaturationNeverEvictsActiveBudget(t *testing.T) {
	now := time.Unix(1000, 0)
	budget := testBudget(t, 1, 1, func() time.Time { return now })
	permit, _, _ := budget.Reserve(context.Background(), "synthetic-member")
	permit.Complete(Invalid)
	for range 20 {
		if _, retry, err := budget.Reserve(context.Background(), "new-member"); !errors.Is(err, ErrSaturated) || retry <= 0 || retry > 30*time.Second {
			t.Fatal("new key must fail closed")
		}
	}
	if _, _, err := budget.Reserve(context.Background(), "synthetic-member"); !errors.Is(err, ErrLimited) {
		t.Fatal("saturation reset existing budget")
	}
	if budget.Stats().Accounts != 1 {
		t.Fatal("unbounded quota storage")
	}
	now = now.Add(30 * time.Second)
	next, _, err := budget.Reserve(context.Background(), "new-member")
	if err != nil {
		t.Fatal(err)
	}
	next.Complete(Invalid)
}

func TestCancellationAndOutcomeAccounting(t *testing.T) {
	for _, outcome := range []Outcome{Success, Invalid, Blocked, Infrastructure, Cancelled, NotStarted} {
		t.Run(string(outcome), func(t *testing.T) {
			budget := testBudget(t, 1, 2, time.Now)
			ctx, cancel := context.WithCancel(context.Background())
			cancel()
			if _, _, err := budget.Reserve(ctx, "synthetic-member"); !errors.Is(err, context.Canceled) || budget.Stats().Accounts != 0 {
				t.Fatal("pre-cancelled request reserved budget")
			}
			permit, _, _ := budget.Reserve(context.Background(), "synthetic-member")
			permit.Complete(outcome)
			permit.Complete(NotStarted)
			next, _, err := budget.Reserve(context.Background(), "synthetic-member")
			if outcome == NotStarted {
				if err != nil {
					t.Fatal("known-not-started work must refund once")
				}
				next.Complete(Invalid)
			} else if !errors.Is(err, ErrLimited) {
				t.Fatal("started/successful work must remain charged until short window expires")
			}
		})
	}
}

func TestNewRejectsInvalidPolicy(t *testing.T) {
	for _, config := range []Config{{}, {Limit: 1, Window: time.Second}, {Limit: 1, MaxAccounts: 1}, {Window: time.Second, MaxAccounts: 1}} {
		if _, err := New(config); err == nil {
			t.Fatal("accepted invalid policy")
		}
	}
}

func TestPruningAndHeapStayBoundedAcrossRefundsAndExpiry(t *testing.T) {
	now := time.Unix(1000, 0)
	budget := testBudget(t, 1, 4, func() time.Time { return now })
	for range 500 {
		permit, _, err := budget.Reserve(context.Background(), "synthetic-member")
		if err != nil {
			t.Fatal(err)
		}
		permit.Complete(NotStarted)
		if len(budget.entries) > 4 || len(budget.expires) > 4 {
			t.Fatal("per-attempt expiry bookkeeping grows without bound")
		}
		now = now.Add(time.Minute)
	}
	fresh := testBudget(t, 1, 4, func() time.Time { return now })
	permit, _, err := fresh.Reserve(context.Background(), "synthetic-member")
	if err != nil {
		t.Fatal("restart must start empty")
	}
	permit.Complete(Success)
}
