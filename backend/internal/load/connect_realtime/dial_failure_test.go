package connect_realtime

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"

	"voice-platform/backend/internal/load/record_results"
)

func TestFailedDialKeepsFailureState(t *testing.T) {
	server := httptest.NewTLSServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusServiceUnavailable)
	}))
	defer server.Close()
	socket := New(record_results.New())
	if socket.Connect(context.Background(), server.Client(), server.URL, false) == nil {
		t.Fatal("failed dial accepted")
	}
	if !socket.Failed() {
		t.Fatal("failed dial cleared socket failure")
	}
}
