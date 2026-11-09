package rostermatrix

import (
	"context"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/coder/websocket"
)

func TestCandidateReaderObservesSeparateReadinessAndSnapshots(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		conn, err := websocket.Accept(w, r, nil)
		if err != nil {
			return
		}
		defer conn.CloseNow()
		for _, frame := range []string{
			`{"kind":"connection.ready","payload":{}}`,
			`{"kind":"maintenance.snapshot","payload":{"version":1,"generation":"11111111-1111-4111-8111-111111111111","revision":1,"active":false}}`,
			`{"kind":"voice.roster.snapshot","payload":{"version":1,"generation":"11111111-1111-4111-8111-111111111111","revision":1,"observed_at":"2026-11-09T00:00:00Z","channels":[]}}`,
		} {
			if conn.Write(ctx, websocket.MessageText, []byte(frame)) != nil {
				return
			}
		}
		<-ctx.Done()
	}))
	defer server.Close()
	conn, _, err := websocket.Dial(ctx, "ws"+strings.TrimPrefix(server.URL, "http"), nil)
	if err != nil {
		t.Fatal(err)
	}
	defer conn.CloseNow()
	got := make(chan string, 3)
	done := make(chan error, 1)
	go func() {
		done <- ReadCandidate(ctx, conn, nil, time.Now(), func(kind string, _ time.Duration) { got <- kind })
	}()
	for _, expected := range []string{"ready", "maintenance", "roster"} {
		select {
		case value := <-got:
			if value != expected {
				t.Fatalf("got %q, want %q", value, expected)
			}
		case <-ctx.Done():
			t.Fatal("missing candidate event")
		}
	}
	cancel()
	if err := <-done; err != nil {
		t.Fatal(err)
	}
}
