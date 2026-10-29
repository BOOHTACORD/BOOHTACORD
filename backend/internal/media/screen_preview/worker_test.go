package screenpreview

import (
	"context"
	"errors"
	"sync"
	"testing"
	"time"
)

type flakyCaptureReconciler struct {
	captureStub
	mu        sync.Mutex
	calls     int
	recovered chan struct{}
}

func (capture *flakyCaptureReconciler) Reconcile(context.Context, []ActiveGeneration) error {
	capture.mu.Lock()
	defer capture.mu.Unlock()
	capture.calls++
	switch capture.calls {
	case 1:
		return errors.New("LiveKit is not ready yet")
	case 2:
		close(capture.recovered)
	}
	return nil
}

func TestRunRetriesEgressReconciliationAfterLiveKitStartupRace(t *testing.T) {
	capturer := &flakyCaptureReconciler{recovered: make(chan struct{})}
	service := Service{store: &testStore{}, capturer: capturer}
	ctx, cancel := context.WithCancel(context.Background())
	done := make(chan struct{})
	go func() {
		service.run(ctx, time.Millisecond, time.Millisecond)
		close(done)
	}()

	select {
	case <-capturer.recovered:
		cancel()
	case <-time.After(time.Second):
		cancel()
		t.Fatal("Egress reconciliation was not retried after LiveKit became available")
	}
	select {
	case <-done:
	case <-time.After(time.Second):
		t.Fatal("screen preview worker did not stop")
	}
}
