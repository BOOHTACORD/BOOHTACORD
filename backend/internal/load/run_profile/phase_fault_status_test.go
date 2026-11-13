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

func TestPhaseFailsWhenFaultExpiresDuringWork(t *testing.T) {
	manifest := validate_target.Manifest{Owner: "owner", Dataset: "qa", Origin: "https://localhost", Commit: "commit"}
	checks := 0
	s := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path == "/fault-status/db_pressure" {
			checks++
			if checks > 1 {
				w.WriteHeader(http.StatusConflict)
			} else {
				w.WriteHeader(http.StatusNoContent)
			}
			return
		}
		if r.Method == http.MethodPost {
			w.WriteHeader(http.StatusNoContent)
			return
		}
		_ = json.NewEncoder(w).Encode(observe_resources.Snapshot{Owner: manifest.Owner, Dataset: manifest.Dataset,
			Origin: manifest.Origin, Commit: manifest.Commit, DBName: "qa", Accounts: 1, At: time.Now(),
			RSSBytes: 1024, FreeBytes: 1 << 30})
	}))
	defer s.Close()
	manifest.Guard = s.URL
	g := observe_resources.Guard{Manifest: manifest, Client: s.Client()}
	phase, err := (&Runner{Profile: "faults"}).phase(context.Background(), g, "warmup", 10*time.Millisecond)
	if err == nil || phase.Failure != "fault_lost" || checks != 2 {
		t.Fatalf("expired fault accepted: phase=%+v checks=%d err=%v", phase, checks, err)
	}
}
