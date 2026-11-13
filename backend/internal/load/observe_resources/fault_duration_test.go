package observe_resources

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"
	"voice-platform/backend/internal/load/validate_target"
)

func TestFaultDurationIsBoundedAndSentAfterAttestation(t *testing.T) {
	m := validate_target.Manifest{Owner: "owner", Dataset: "qa", Origin: "https://localhost", Commit: "commit", Nonce: "nonce"}
	posts := 0
	s := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method == http.MethodPost {
			posts++
			if r.URL.Path != "/fault/sfu_outage" || r.Header.Get("X-Load-Nonce") != "nonce" || r.Header.Get("X-QA-Fault-Seconds") != "8" {
				t.Error("fault request missing bounded duration or attestation")
			}
			w.WriteHeader(http.StatusNoContent)
			return
		}
		_ = json.NewEncoder(w).Encode(Snapshot{Owner: m.Owner, Dataset: m.Dataset, Origin: m.Origin,
			Commit: m.Commit, DBName: "qa", Accounts: 1, At: time.Now(), RSSBytes: 1024, FreeBytes: 1 << 30})
	}))
	defer s.Close()
	m.Guard = s.URL
	g := Guard{Manifest: m, Client: s.Client()}
	if err := g.FaultFor(context.Background(), "sfu_outage", 4500*time.Millisecond); err != nil {
		t.Fatal(err)
	}
	if err := g.FaultFor(context.Background(), "sfu_outage", 28*time.Second); err == nil {
		t.Fatal("unbounded fault accepted")
	}
	if err := g.FaultFor(context.Background(), "restore", time.Second); err == nil {
		t.Fatal("restore duration accepted")
	}
	if posts != 1 {
		t.Fatalf("unexpected fault requests: %d", posts)
	}
}
