package run_profile

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/coder/websocket"
	"github.com/coder/websocket/wsjson"
	"voice-platform/backend/internal/load/connect_realtime"
	"voice-platform/backend/internal/load/record_results"
)

func TestReconnectSocketStillReceivesEventsAfterSpikePhaseEnds(t *testing.T) {
	send := make(chan struct{})
	s := httptest.NewTLSServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		conn, err := websocket.Accept(w, r, nil)
		if err != nil {
			return
		}
		defer conn.CloseNow()
		for _, kind := range []string{"connection.ready", "presence.snapshot"} {
			if wsjson.Write(r.Context(), conn, map[string]any{"kind": kind}) != nil {
				return
			}
		}
		select {
		case <-send:
		case <-r.Context().Done():
			return
		}
		_ = wsjson.Write(r.Context(), conn, map[string]any{"event_id": "event", "kind": "message.created", "payload": map[string]string{"message_id": "message"}})
		<-r.Context().Done()
	}))
	defer s.Close()
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()
	work, finishPhase := operationContext(ctx, "reconnect", "spike", time.Second)
	socket := connect_realtime.New(record_results.New())
	defer socket.Close()
	if err := socket.Connect(work, s.Client(), s.URL, false); err != nil {
		t.Fatal(err)
	}
	finishPhase()
	start := time.Now()
	close(send)
	if _, err := socket.Wait(ctx, "message", start); err != nil {
		t.Fatalf("socket was lost at phase boundary: %v", err)
	}
}
