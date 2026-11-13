package run_profile

import (
	"context"
	"net/http"
	"net/http/httptest"
	"sync/atomic"
	"testing"
	"time"

	"github.com/coder/websocket"
	"github.com/coder/websocket/wsjson"
	"voice-platform/backend/internal/load/connect_realtime"
	"voice-platform/backend/internal/load/exercise_actor"
	"voice-platform/backend/internal/load/record_results"
	"voice-platform/backend/internal/load/validate_target"
)

func TestFailedFaultSocketReconnectsAndRecordsRecovery(t *testing.T) {
	s := httptest.NewTLSServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		conn, err := websocket.Accept(w, r, nil)
		if err != nil {
			return
		}
		defer conn.CloseNow()
		for _, kind := range []string{"connection.ready", "presence.snapshot"} {
			if wsjson.Write(r.Context(), conn, map[string]string{"kind": kind}) != nil {
				return
			}
		}
		<-r.Context().Done()
	}))
	defer s.Close()
	results := record_results.New()
	socket := connect_realtime.New(results)
	socket.Close()
	actor := &exercise_actor.Actor{Manifest: validate_target.Manifest{Origin: s.URL, MaxRequests: 10},
		Client: s.Client(), Socket: socket, Results: results, Budget: &atomic.Int64{}}
	ctx, cancel := context.WithTimeout(context.Background(), time.Second)
	defer cancel()
	defer socket.Close()
	if err := recoverFaultSocket(ctx, "faults", actor); err != nil {
		t.Fatal(err)
	}
	if socket.Failed() || results.Snapshot()["reconnect"].Count != 1 {
		t.Fatal("recovery was not observed")
	}
	if err := recoverFaultSocket(ctx, "faults", actor); err != nil {
		t.Fatal(err)
	}
	if results.Snapshot()["reconnect"].Count != 1 {
		t.Fatal("healthy socket reconnected again")
	}
}

func TestFaultReconnectFailureIsNotHidden(t *testing.T) {
	s := httptest.NewTLSServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusServiceUnavailable)
	}))
	defer s.Close()
	results := record_results.New()
	socket := connect_realtime.New(results)
	socket.Close()
	actor := &exercise_actor.Actor{Manifest: validate_target.Manifest{Origin: s.URL, MaxRequests: 10},
		Client: s.Client(), Socket: socket, Results: results, Budget: &atomic.Int64{}}
	if err := recoverFaultSocket(context.Background(), "normal", actor); err != nil {
		t.Fatal(err)
	}
	if !socket.Failed() {
		t.Fatal("normal profile unexpectedly reconnected")
	}
	if err := recoverFaultSocket(context.Background(), "faults", actor); err == nil {
		t.Fatal("failed reconnect accepted")
	}
	if results.Snapshot()["reconnect"].Errors != 1 {
		t.Fatal("reconnect failure was not recorded")
	}
	if !socket.Failed() {
		t.Fatal("failed dial cleared the socket failure")
	}
}
