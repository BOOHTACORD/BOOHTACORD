package observe_resources

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"sync/atomic"
	"testing"
	"time"

	"voice-platform/backend/internal/load/validate_target"
)

func TestMaintenanceChangeRequiresMatchingFreshGuard(t *testing.T) {
	var changes atomic.Int32
	manifest := validate_target.Manifest{Nonce: "fixture", Owner: "owner", Dataset: "qa", Origin: "https://localhost:4810", Commit: "commit"}
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get("X-Load-Nonce") != manifest.Nonce {
			t.Error("missing guard nonce")
		}
		if r.URL.Path == "/maintenance/on" {
			changes.Add(1)
			w.WriteHeader(http.StatusNoContent)
			return
		}
		_ = json.NewEncoder(w).Encode(Snapshot{Owner: "owner", Dataset: "qa", Origin: manifest.Origin,
			Commit: "commit", DBName: "qa", Accounts: 1, At: time.Now(), RSSBytes: 1,
			FreeBytes: 1 << 30, MetricsStatus: "AVAILABLE"})
	}))
	defer server.Close()
	manifest.Guard = server.URL
	guard := Guard{Manifest: manifest, Client: server.Client()}
	if err := guard.ChangeMaintenance(context.Background()); err != nil || changes.Load() != 1 {
		t.Fatalf("authorized change: %v", err)
	}
	guard.Manifest.Owner = "foreign"
	if err := guard.ChangeMaintenance(context.Background()); err == nil || changes.Load() != 1 {
		t.Fatal("foreign fixture was mutated")
	}
}
