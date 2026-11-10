package coordinateroster

import (
	"testing"
	"time"
)

func TestRetryOnNextRefreshIsScopedAndDoesNotScheduleReads(t *testing.T) {
	lister := &fakeLister{}
	c, _, _ := fixture(t, lister)
	first, err := c.Subscribe(accountA)
	if err != nil {
		t.Fatal(err)
	}
	defer first.Close()
	receive(t, first)
	second, err := c.Subscribe(accountA)
	if err != nil {
		t.Fatal(err)
	}
	defer second.Close()
	receive(t, second)
	if !first.RequestRefresh() {
		t.Fatal("first refresh rejected")
	}
	initial := receive(t, first)
	if !first.Current(initial) {
		t.Fatal("fresh initial snapshot is not current")
	}
	before := lister.calls.Load()
	if !first.RetryOnNextRefresh() {
		t.Fatal("retry was rejected")
	}
	if !first.Current(initial) {
		t.Fatal("marking retry invalidated the current snapshot")
	}
	time.Sleep(50 * time.Millisecond)
	if got := lister.calls.Load(); got != before {
		t.Fatalf("retry scheduled an extra read: %d -> %d", before, got)
	}
	c.Invalidate()
	if got := receive(t, first); got.Unavailable {
		t.Fatal("retry did not get roster")
	}
	select {
	case got := <-second.Events():
		t.Fatalf("unaffected subscriber got duplicate: %+v", got)
	case <-time.After(100 * time.Millisecond):
	}
	first.Close()
	if first.RetryOnNextRefresh() {
		t.Fatal("closed subscriber accepted retry")
	}
}
