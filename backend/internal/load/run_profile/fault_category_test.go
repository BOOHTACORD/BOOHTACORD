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

func TestFaultPhaseRetainsBoundedGuardCategory(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.Header().Set("X-QA-Guard-Stage", "fixture_verification")
		w.WriteHeader(http.StatusServiceUnavailable)
	}))
	defer server.Close()
	r := &Runner{Profile: "faults"}
	guard := observe_resources.Guard{Manifest: validate_target.Manifest{Guard: server.URL}, Client: server.Client()}
	phase, err := r.phase(context.Background(), guard, "warmup", time.Second)
	if err == nil || phase.Failure != "fault_fixture_verification" {
		t.Fatalf("missing guard failure: %+v", phase)
	}
}
