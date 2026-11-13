package run_profile

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"
	"voice-platform/backend/internal/load/connect_realtime"
	"voice-platform/backend/internal/load/exercise_actor"
	"voice-platform/backend/internal/load/observe_resources"
	"voice-platform/backend/internal/load/record_results"
	"voice-platform/backend/internal/load/validate_target"
)

func TestFaultPhaseCancelsBlockedOperationAtPhaseDeadline(t *testing.T) {
	m := validate_target.Manifest{Owner: "owner", Dataset: "qa", Origin: "https://localhost", Commit: "commit", MaxRequests: 100}
	s := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path == "/api/v1/channels" {
			select {
			case <-r.Context().Done():
			case <-time.After(600 * time.Millisecond):
			}
			return
		}
		if r.URL.Path == "/fault-status/db_pressure" || r.Method == http.MethodPost {
			w.WriteHeader(http.StatusNoContent)
			return
		}
		_ = json.NewEncoder(w).Encode(observe_resources.Snapshot{Owner: m.Owner, Dataset: m.Dataset,
			Origin: m.Origin, Commit: m.Commit, DBName: "qa", Accounts: 1, At: time.Now(),
			RSSBytes: 1024, FreeBytes: 1 << 30})
	}))
	defer s.Close()
	m.Guard = s.URL
	runner := &Runner{Profile: "faults", results: record_results.New()}
	actor := &exercise_actor.Actor{Manifest: validate_target.Manifest{Origin: s.URL, MaxRequests: 100},
		Client: s.Client(), Socket: connect_realtime.New(runner.results), Results: runner.results, Budget: &runner.budget}
	runner.actors = []*exercise_actor.Actor{actor}
	start := time.Now()
	phase, err := runner.phase(context.Background(), observe_resources.Guard{Manifest: m, Client: s.Client()}, "warmup", 40*time.Millisecond)
	if err != nil || time.Since(start) > 350*time.Millisecond || phase.Requests == 0 || phase.Errors != 1 {
		t.Fatalf("blocked fault operation crossed phase deadline: phase=%+v elapsed=%v err=%v", phase, time.Since(start), err)
	}
}
