package run_profile

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"
	"voice-platform/backend/internal/load/observe_resources"
	"voice-platform/backend/internal/load/validate_target"
)

func TestMonitorDoesNotReportFailureForOwnerCancellation(t *testing.T) {
	entered := make(chan struct{})
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		close(entered)
		<-r.Context().Done()
	}))
	defer server.Close()
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	runner := &Runner{}
	stop := make(chan string, 1)
	done := make(chan struct{})
	go func() {
		runner.monitor(ctx, observe_resources.Guard{Manifest: validate_target.Manifest{Guard: server.URL}, Client: server.Client()}, stop, cancel)
		close(done)
	}()
	select {
	case <-entered:
	case <-time.After(3 * time.Second):
		t.Fatal("guard was not checked")
	}
	cancel()
	select {
	case <-done:
	case <-time.After(3 * time.Second):
		t.Fatal("monitor did not stop")
	}
	select {
	case reason := <-stop:
		t.Fatalf("cancellation reported as failure: %s", reason)
	default:
	}
	if runner.guardFailure != "" {
		t.Fatalf("unexpected failure category: %s", runner.guardFailure)
	}
}
