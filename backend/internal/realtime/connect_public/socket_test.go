package connectpublic

import (
	"context"
	"net/http"
	"testing"
	"time"

	"github.com/coder/websocket/wsjson"
)

func TestSnapshotChangeAndUnavailable(t *testing.T) {
	server, observer, source := setup(t, 100)
	socket, _, err := dial(t, server, "https://voice.example.test", "")
	if err != nil {
		t.Fatal(err)
	}
	defer socket.CloseNow()
	if got := read(t, socket); got.Kind != "connection.ready" || len(got.Payload) != 0 {
		t.Fatalf("ready: %+v", got)
	}
	first := read(t, socket)
	if first.Kind != "maintenance.snapshot" || first.Payload["active"] != false || len(first.Payload) != 4 {
		t.Fatalf("snapshot: %+v", first)
	}
	source.mode.Store(1)
	observer.RequestRefresh()
	changed := read(t, socket)
	if changed.Kind != "maintenance.changed" || changed.Payload["active"] != true || changed.Payload["generation"] != first.Payload["generation"] || changed.Payload["revision"].(float64) <= first.Payload["revision"].(float64) {
		t.Fatalf("changed: %+v", changed)
	}
	source.mode.Store(2)
	observer.RequestRefresh()
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()
	var value frame
	if err := wsjson.Read(ctx, socket, &value); err == nil {
		t.Fatalf("unavailable emitted: %+v", value)
	}
}

func TestRejectsForeignOriginAndQueryBeforeUpgrade(t *testing.T) {
	server, _, _ := setup(t, 100)
	for _, tc := range []struct{ origin, query string }{{"https://evil.test", ""}, {"https://voice.example.test", "?token=secret"}} {
		socket, response, err := dial(t, server, tc.origin, tc.query)
		if err == nil {
			socket.CloseNow()
			t.Fatal("unexpected upgrade")
		}
		if response == nil || (response.StatusCode != http.StatusForbidden && response.StatusCode != http.StatusBadRequest) {
			t.Fatalf("response: %+v", response)
		}
	}
	socket, _, err := dial(t, server, "", "")
	if err != nil {
		t.Fatalf("native without Origin: %v", err)
	}
	socket.CloseNow()
}
