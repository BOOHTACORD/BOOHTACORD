package connectpublic

import (
	"context"
	"net/http"
	"strings"
	"testing"
	"time"

	"github.com/coder/websocket"
	"github.com/coder/websocket/wsjson"
)

func TestNegotiatedPublicHeartbeatContainsNoPrivatePayload(t *testing.T) {
	t.Parallel()
	server, _, _ := setup(t, 100)
	ctx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
	defer cancel()
	socket, _, err := websocket.Dial(ctx, "ws"+strings.TrimPrefix(server.URL, "http"), &websocket.DialOptions{
		HTTPHeader:   http.Header{"Origin": {"https://voice.example.test"}},
		Subprotocols: []string{"boohtacord.heartbeat.v1"},
	})
	if err != nil {
		t.Fatal(err)
	}
	defer socket.CloseNow()
	if socket.Subprotocol() != "boohtacord.heartbeat.v1" {
		t.Fatal("heartbeat protocol not selected")
	}
	if got := read(t, socket); got.Kind != "connection.ready" {
		t.Fatalf("ready: %+v", got)
	}
	if got := read(t, socket); got.Kind != "maintenance.snapshot" {
		t.Fatalf("snapshot: %+v", got)
	}
	var got event
	if err := wsjson.Read(ctx, socket, &got); err != nil {
		t.Fatal(err)
	}
	if got.Kind != "connection.heartbeat" || got.ID == "" || got.OccurredAt.IsZero() || len(got.Payload) != 0 {
		t.Fatalf("unexpected heartbeat envelope: %+v", got)
	}
}

func TestLegacyPublicSocketDoesNotReceiveHeartbeat(t *testing.T) {
	t.Parallel()
	server, _, _ := setup(t, 100)
	socket, _, err := dial(t, server, "https://voice.example.test", "")
	if err != nil {
		t.Fatal(err)
	}
	defer socket.CloseNow()
	read(t, socket)
	read(t, socket)
	ctx, cancel := context.WithTimeout(context.Background(), 16*time.Second)
	defer cancel()
	var got event
	if err := wsjson.Read(ctx, socket, &got); err == nil {
		t.Fatalf("unexpected legacy event: %+v", got)
	}
}
