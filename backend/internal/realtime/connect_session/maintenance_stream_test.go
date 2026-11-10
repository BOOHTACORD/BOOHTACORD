package connectsession

import (
	"context"
	"errors"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync/atomic"
	"testing"
	"time"

	"github.com/coder/websocket"
	"github.com/coder/websocket/wsjson"
	auth "voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	observestate "voice-platform/backend/internal/maintenance/observe_state"
)

type maintenanceReader struct {
	state atomic.Int32
	calls atomic.Int32
}

func (r *maintenanceReader) Active(context.Context) (bool, error) {
	r.calls.Add(1)
	if r.state.Load() == 2 {
		return false, errors.New("private failure")
	}
	return r.state.Load() == 1, nil
}

func TestMaintenanceCapabilityGatesSnapshotChangeAndUnavailable(t *testing.T) {
	reader := &maintenanceReader{}
	observer := observestate.New(reader, time.Hour, time.Second)
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	go observer.Run(ctx)
	handler := NewHandlerWithMaintenance(nil, 0, time.Now, nil, nil, nil, nil, observer)
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		handler.ServeHTTP(w, r.WithContext(sessionapi.WithPrincipal(r.Context(), auth.Principal{AccountID: "member"})))
	}))
	defer server.Close()
	dial := func(query string) *websocket.Conn {
		connection, _, err := websocket.Dial(ctx, "ws"+strings.TrimPrefix(server.URL, "http")+query, nil)
		if err != nil {
			t.Fatal(err)
		}
		return connection
	}
	legacy := dial("")
	defer legacy.CloseNow()
	if event := readMaintenanceEvent(t, legacy); event.Kind != "connection.ready" {
		t.Fatalf("legacy ready: %+v", event)
	}
	time.Sleep(100 * time.Millisecond)
	if count := reader.calls.Load(); count != 0 {
		t.Fatalf("legacy requested maintenance read: %d", count)
	}
	current := dial("?capabilities=maintenance_v1")
	defer current.CloseNow()
	if event := readMaintenanceEvent(t, current); event.Kind != "connection.ready" {
		t.Fatalf("ready: %+v", event)
	}
	initial := readMaintenanceEvent(t, current)
	if initial.Kind != "maintenance.snapshot" || initial.Payload["active"] != false {
		t.Fatalf("snapshot: %+v", initial)
	}
	reader.state.Store(1)
	observer.RequestRefresh()
	changed := readMaintenanceEvent(t, current)
	if changed.Kind != "maintenance.changed" || changed.Payload["active"] != true || changed.Payload["generation"] != initial.Payload["generation"] {
		t.Fatalf("change: %+v", changed)
	}
	legacyContext, stopLegacy := context.WithTimeout(ctx, 100*time.Millisecond)
	var unexpected Event
	if err := wsjson.Read(legacyContext, legacy, &unexpected); err == nil {
		t.Fatalf("legacy received new event: %+v", unexpected)
	}
	stopLegacy()
	reader.state.Store(2)
	observer.RequestRefresh()
	readContext, stop := context.WithTimeout(ctx, 2*time.Second)
	defer stop()
	var event Event
	if err := wsjson.Read(readContext, current, &event); err == nil {
		t.Fatalf("unknown state emitted: %+v", event)
	}
}

func readMaintenanceEvent(t *testing.T, connection *websocket.Conn) Event {
	t.Helper()
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()
	var event Event
	if err := wsjson.Read(ctx, connection, &event); err != nil {
		t.Fatal(err)
	}
	return event
}
