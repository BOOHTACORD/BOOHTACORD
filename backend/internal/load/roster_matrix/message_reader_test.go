package rostermatrix

import (
	"context"
	"github.com/coder/websocket"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"
)

func TestMessageReaderUsesSameApplicationSocket(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		conn, err := websocket.Accept(w, r, nil)
		if err != nil {
			return
		}
		defer conn.CloseNow()
		_ = conn.Write(ctx, websocket.MessageText, []byte(`{"kind":"message.created","occurred_at":"2026-01-01T00:00:00Z","payload":{"message_id":"11111111-1111-4111-8111-111111111111"}}`))
		<-ctx.Done()
	}))
	defer server.Close()
	conn, _, err := websocket.Dial(ctx, "ws"+strings.TrimPrefix(server.URL, "http"), nil)
	if err != nil {
		t.Fatal(err)
	}
	defer conn.CloseNow()
	seen := make(chan string, 1)
	done := make(chan error, 1)
	go func() {
		done <- ReadCandidateWithMessages(ctx, conn, nil, time.Now(), func(string, time.Duration) {}, func(id string, _, _ time.Time) { seen <- id })
	}()
	select {
	case id := <-seen:
		if id != "11111111-1111-4111-8111-111111111111" {
			t.Fatal(id)
		}
	case <-ctx.Done():
		t.Fatal("missing message")
	}
	cancel()
	if err := <-done; err != nil {
		t.Fatal(err)
	}
}
