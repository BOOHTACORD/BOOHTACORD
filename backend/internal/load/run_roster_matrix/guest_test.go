package runrostermatrix

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/coder/websocket"
)

func TestPublicActorReceivesOnlyPublicStates(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	server := httptest.NewTLSServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		conn, err := websocket.Accept(w, r, nil)
		if err != nil {
			return
		}
		defer conn.CloseNow()
		for _, frame := range []string{
			`{"event_id":"11111111-1111-4111-8111-111111111111","occurred_at":"2026-11-09T00:00:00Z","kind":"connection.ready","payload":{}}`,
			`{"event_id":"11111111-1111-4111-8111-111111111111","occurred_at":"2026-11-09T00:00:00Z","kind":"maintenance.snapshot","payload":{"version":1,"generation":"11111111-1111-4111-8111-111111111111","revision":1,"active":false}}`,
		} {
			if conn.Write(ctx, websocket.MessageText, []byte(frame)) != nil {
				return
			}
		}
		<-ctx.Done()
	}))
	defer server.Close()
	measure := NewPublicMeasurements(1, true)
	actor, err := StartGuest(ctx, server.Client(), server.URL, 0, false, measure)
	if err != nil {
		t.Fatal(err)
	}
	for !measure.Complete() && ctx.Err() == nil {
		time.Sleep(10 * time.Millisecond)
	}
	actor.Close()
	if !measure.Complete() {
		t.Fatal("guest initial state missing")
	}
	cancel()
}
