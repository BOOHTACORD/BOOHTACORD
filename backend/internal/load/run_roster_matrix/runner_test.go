package runrostermatrix

import (
	"context"
	"net/http"
	"net/http/httptest"
	"sync/atomic"
	"testing"

	"voice-platform/backend/internal/load/validate_target"
)

func TestRunnerRejectsUnownedTargetsBeforeAnyNetwork(t *testing.T) {
	for _, mode := range []string{"candidate", "baseline", "unknown"} {
		report := Run(context.Background(), validate_target.Manifest{Origin: "https://foreign.invalid"}, mode)
		if report.Outcome != "FAIL" || report.StopReason != "preflight" {
			t.Fatalf("unsafe input accepted for %s", mode)
		}
	}
	report := RunWithWorkload(context.Background(), validate_target.Manifest{}, "candidate", false, false, 21)
	if report.Outcome != "FAIL" || report.StopReason != "preflight" {
		t.Fatal("excessive message workload accepted")
	}
	if report := RunWithWarmup(context.Background(), validate_target.Manifest{}, "candidate", false, false, 1, 2001); report.StopReason != "preflight" {
		t.Fatal("excessive warmup accepted")
	}
}

func TestRunnerDoesNotLogInWhenGuardRejectsOwnership(t *testing.T) {
	var requests atomic.Int64
	server := httptest.NewTLSServer(http.HandlerFunc(func(http.ResponseWriter, *http.Request) { requests.Add(1) }))
	defer server.Close()
	guard := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		_, _ = w.Write([]byte(`{"Owner":"foreign","MetricsStatus":"AVAILABLE"}`))
	}))
	defer guard.Close()
	m := validate_target.Manifest{
		Origin: server.URL, Guard: guard.URL, Nonce: "01234567890123456789012345678901",
		Dataset: "qa", Owner: "qa-client-1234567890abcdef", Commit: "319fa06ce219e493f10d43b1fb54ff732f1b4d34",
		Text: "11111111-1111-4111-8111-111111111111", PrivateDM: "22222222-2222-4222-8222-222222222222",
		Accounts:    []validate_target.Account{{Login: "qa_load_000", Password: "fixture", ID: "33333333-3333-4333-8333-333333333333"}},
		UploadBytes: 1, MaxRequests: 100, MaxSeconds: 20,
	}
	report := Run(context.Background(), m, "candidate")
	if report.StopReason != "guard_preflight" || requests.Load() != 0 {
		t.Fatal("unowned deployment was contacted")
	}
	if report := RunWithWarmup(context.Background(), m, "candidate", false, false, 0, 100); report.StopReason != "preflight" {
		t.Fatal("warmup without a message workload was accepted")
	}
	m.MaxRequests = 1
	report = Run(context.Background(), m, "candidate")
	if report.StopReason != "preflight" || requests.Load() != 0 {
		t.Fatal("insufficient request budget was accepted")
	}
}
