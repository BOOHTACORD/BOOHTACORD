package observe_resources

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"
	"voice-platform/backend/internal/load/validate_target"
)

func TestFaultStatusRequiresExplicitActiveResponse(t *testing.T) {
	status := http.StatusNoContent
	s := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/fault-status/sfu_outage" || r.Header.Get("X-Load-Nonce") != "secret" {
			t.Error("status request not bound to expected fault and nonce")
		}
		w.WriteHeader(status)
	}))
	defer s.Close()
	g := Guard{Manifest: validate_target.Manifest{Guard: s.URL, Nonce: "secret"}, Client: s.Client()}
	if err := g.FaultActive(context.Background(), "sfu_outage"); err != nil {
		t.Fatal(err)
	}
	status = http.StatusConflict
	if err := g.FaultActive(context.Background(), "sfu_outage"); err == nil {
		t.Fatal("inactive fault accepted")
	}
	if err := g.FaultActive(context.Background(), "../../snapshot"); err == nil {
		t.Fatal("unknown fault accepted")
	}
}

func TestWaitFaultRetriesInactiveButDoesNotAcceptUnknownStatus(t *testing.T) {
	checks := 0
	s := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		checks++
		if checks == 1 {
			w.WriteHeader(http.StatusConflict)
			return
		}
		w.WriteHeader(http.StatusNoContent)
	}))
	defer s.Close()
	g := Guard{Manifest: validate_target.Manifest{Guard: s.URL}, Client: s.Client()}
	if err := g.WaitFault(context.Background(), "db_pressure"); err != nil || checks != 2 {
		t.Fatalf("fault did not become active: checks=%d err=%v", checks, err)
	}
}
