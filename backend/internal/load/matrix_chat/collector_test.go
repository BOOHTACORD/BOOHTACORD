package matrixchat

import (
	"context"
	"testing"
	"time"
)

const first = "11111111-1111-4111-8111-111111111111"
const other = "22222222-2222-4222-8222-222222222222"

func TestObservesEventsBeforeReceiptAndRejectsDuplicates(t *testing.T) {
	c, err := New(2)
	if err != nil {
		t.Fatal(err)
	}
	start := time.Now()
	if err := c.Begin(start); err != nil {
		t.Fatal(err)
	}
	c.Observe(1, first, start.Add(20*time.Millisecond))
	c.Observe(0, other, start.Add(10*time.Millisecond))
	c.Observe(0, first, start.Add(12*time.Millisecond))
	c.Observe(0, first, start.Add(13*time.Millisecond))
	samples, duplicates, err := c.Finish(context.Background(), first)
	if err != nil || len(samples) != 2 || samples[0] != 12*time.Millisecond || samples[1] != 20*time.Millisecond || duplicates != 1 {
		t.Fatalf("unexpected observations: %v %d %v", samples, duplicates, err)
	}
}

func TestBoundedWaitAndInvalidEvents(t *testing.T) {
	c, err := New(2)
	if err != nil {
		t.Fatal(err)
	}
	if err := c.Begin(time.Now()); err != nil {
		t.Fatal(err)
	}
	c.Observe(0, first, time.Now())
	ctx, cancel := context.WithTimeout(context.Background(), 20*time.Millisecond)
	defer cancel()
	if _, _, err := c.Finish(ctx, first); err == nil {
		t.Fatal("missing recipient accepted")
	}
	if err := c.Begin(time.Now()); err != nil {
		t.Fatal(err)
	}
	c.Observe(2, first, time.Now())
	if _, _, err := c.Finish(context.Background(), first); err == nil {
		t.Fatal("invalid recipient accepted")
	}
}

func TestLateDuplicateIsObservedAfterEveryRecipientHasReceived(t *testing.T) {
	c, err := New(1)
	if err != nil {
		t.Fatal(err)
	}
	if err := c.Begin(time.Now()); err != nil {
		t.Fatal(err)
	}
	c.Observe(0, first, time.Now())
	done := make(chan struct{})
	go func() {
		defer close(done)
		time.Sleep(20 * time.Millisecond)
		c.Observe(0, first, time.Now())
	}()
	ctx, cancel := context.WithTimeout(context.Background(), time.Second)
	defer cancel()
	_, duplicates, err := c.Finish(ctx, first)
	<-done
	if err != nil || duplicates != 1 {
		t.Fatalf("late duplicate was missed: %d %v", duplicates, err)
	}
}

func TestPresenceCountsAreBoundedAndDoNotStoreIdentity(t *testing.T) {
	c, err := New(2)
	if err != nil {
		t.Fatal(err)
	}
	c.ObservePresence(0)
	c.ObservePresence(1)
	c.ObservePresence(1)
	c.ObservePresence(2)
	if got := c.PresenceCount(); got != 3 {
		t.Fatalf("presence count: %d", got)
	}
}

func TestAuxiliaryCountsAreBoundedByKindAndIndex(t *testing.T) {
	c, _ := New(2)
	c.ObserveAuxiliary(0, "roster")
	c.ObserveAuxiliary(1, "maintenance")
	c.ObserveAuxiliary(2, "roster")
	c.ObserveAuxiliary(0, "unknown")
	got := c.AuxiliaryCounts()
	if got != [2]uint64{1, 1} {
		t.Fatalf("auxiliary counts: %v", got)
	}
}

func TestTimedObservationsMeasureGenerationAndDeliverySeparately(t *testing.T) {
	c, _ := New(2)
	started := time.Now()
	if err := c.Begin(started); err != nil {
		t.Fatal(err)
	}
	created := started.Add(5 * time.Millisecond)
	c.ObserveTimed(0, first, started.Add(20*time.Millisecond), created)
	c.ObserveTimed(1, first, started.Add(30*time.Millisecond), created)
	result, err := c.FinishDetailed(context.Background(), first)
	if err != nil || result.CreatedAfter != 5*time.Millisecond || len(result.Ages) != 2 || result.Ages[0] != 15*time.Millisecond || result.Ages[1] != 25*time.Millisecond {
		t.Fatalf("timing: %+v %v", result, err)
	}
}
