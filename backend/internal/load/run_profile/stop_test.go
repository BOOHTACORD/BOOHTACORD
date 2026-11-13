package run_profile

import (
	"context"
	"encoding/json"
	"github.com/google/uuid"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync/atomic"
	"testing"
	"time"
	"voice-platform/backend/internal/load/observe_resources"
	"voice-platform/backend/internal/load/validate_target"
)

func TestGuardStopCancelsAdmissionAndStillRestoresAndLogsOut(t *testing.T) {
	var snapshots, restores, logout atomic.Int64
	api := httptest.NewTLSServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		switch r.URL.Path {
		case "/api/v1/auth/login":
			io.Copy(io.Discard, r.Body)
			select {
			case <-r.Context().Done():
			case <-time.After(3 * time.Second):
			}
		case "/api/v1/auth/logout":
			logout.Add(1)
			w.WriteHeader(204)
		default:
			w.WriteHeader(401)
		}
	}))
	defer api.Close()
	m := validate_target.Manifest{Origin: api.URL, Dataset: "qa", Nonce: strings.Repeat("a", 32), Owner: "qa-client-0123456789abcdef", Commit: strings.Repeat("a", 40), Text: uuid.NewString(), PrivateDM: uuid.NewString(), Voice: []string{uuid.NewString()}, Accounts: []validate_target.Account{{Login: "qa_load_000", Password: "private", ID: uuid.NewString()}}, UploadBytes: 1, MaxRequests: 100, MaxSeconds: 10}
	guard := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Header.Get("X-Load-Nonce") != m.Nonce {
			w.WriteHeader(403)
			return
		}
		if r.URL.Path == "/fault/restore" {
			restores.Add(1)
			w.WriteHeader(204)
			return
		}
		free := int64(1 << 30)
		if snapshots.Add(1) > 1 {
			free = 1
		}
		json.NewEncoder(w).Encode(observe_resources.Snapshot{Owner: m.Owner, Dataset: "qa", DBName: "qa", Origin: m.Origin, Commit: m.Commit, Accounts: 2, At: time.Now(), RSSBytes: 1024, FreeBytes: free})
	}))
	defer guard.Close()
	m.Guard = guard.URL
	started := time.Now()
	r := Runner{Manifest: m, Profile: "normal"}
	report := r.Run(context.Background())
	if report.Outcome != "FAIL" || report.Cleanup != "PASS" || restores.Load() != 1 || logout.Load() != 1 || time.Since(started) > 3*time.Second {
		t.Fatal(report)
	}
	if report.GuardFailure != "resource_threshold" {
		t.Fatalf("missing safe guard category: %+v", report)
	}
}
