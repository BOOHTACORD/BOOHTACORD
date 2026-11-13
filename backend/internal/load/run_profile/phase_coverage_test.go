package run_profile

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"
	"voice-platform/backend/internal/load/observe_resources"
	"voice-platform/backend/internal/load/validate_target"
)

func TestFaultSetupCannotConsumePhaseAndStillPassWithoutWork(t *testing.T) {
	manifest := validate_target.Manifest{Owner: "qa-owner", Dataset: "qa", Origin: "https://localhost", Commit: "commit"}
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method == http.MethodPost {
			time.Sleep(30 * time.Millisecond)
			w.WriteHeader(http.StatusNoContent)
			return
		}
		_ = json.NewEncoder(w).Encode(observe_resources.Snapshot{
			Owner: manifest.Owner, Dataset: manifest.Dataset, Origin: manifest.Origin,
			Commit: manifest.Commit, DBName: "qa", Accounts: 1, At: time.Now(),
			RSSBytes: 1024, FreeBytes: 1 << 30,
		})
	}))
	defer server.Close()
	manifest.Guard = server.URL
	guard := observe_resources.Guard{Manifest: manifest, Client: server.Client()}
	r := &Runner{Profile: "faults"}
	phase, err := r.measuredPhase(context.Background(), guard, "warmup", time.Millisecond)
	if err == nil || phase.Requests != 0 || phase.Failure != "no_workload" {
		t.Fatalf("empty phase must fail: phase=%+v err=%v", phase, err)
	}
}

func TestPhaseDurationStartsAfterFaultSetup(t *testing.T) {
	manifest := validate_target.Manifest{Owner: "qa-owner", Dataset: "qa", Origin: "https://localhost", Commit: "commit"}
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method == http.MethodPost {
			time.Sleep(80 * time.Millisecond)
			w.WriteHeader(http.StatusNoContent)
			return
		}
		_ = json.NewEncoder(w).Encode(observe_resources.Snapshot{
			Owner: manifest.Owner, Dataset: manifest.Dataset, Origin: manifest.Origin,
			Commit: manifest.Commit, DBName: "qa", Accounts: 1, At: time.Now(),
			RSSBytes: 1024, FreeBytes: 1 << 30,
		})
	}))
	defer server.Close()
	manifest.Guard = server.URL
	guard := observe_resources.Guard{Manifest: manifest, Client: server.Client()}
	r := &Runner{Profile: "faults"}
	started := time.Now()
	_, err := r.phase(context.Background(), guard, "warmup", 60*time.Millisecond)
	if err != nil || time.Since(started) < 125*time.Millisecond {
		t.Fatalf("fault setup consumed workload time: elapsed=%v err=%v", time.Since(started), err)
	}
}
