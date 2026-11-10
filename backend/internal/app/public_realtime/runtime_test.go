package publicrealtime

import (
	"context"
	"net/http/httptest"
	"strings"
	"sync/atomic"
	"testing"
	"time"

	"github.com/coder/websocket"
	"github.com/coder/websocket/wsjson"
)

type testReader struct{ calls atomic.Int32 }

func (r *testReader) Active(context.Context) (bool, error) { r.calls.Add(1); return true, nil }

func TestRuntimeSharesObserverAndStopsActiveSockets(t *testing.T) {
	reader := &testReader{}
	handler, stop, err := Start(context.Background(), reader, "https://example.test", nil)
	if err != nil {
		t.Fatal(err)
	}
	server := httptest.NewServer(handler)
	defer server.Close()
	var sockets []*websocket.Conn
	defer func() {
		for _, socket := range sockets {
			socket.CloseNow()
		}
	}()
	for i := 0; i < 20; i++ {
		ctx, cancel := context.WithTimeout(context.Background(), time.Second)
		socket, _, err := websocket.Dial(ctx, "ws"+strings.TrimPrefix(server.URL, "http"), nil)
		cancel()
		if err != nil {
			t.Fatal(err)
		}
		sockets = append(sockets, socket)
	}
	for _, socket := range sockets {
		ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
		var ready, snapshot struct {
			Kind    string         `json:"kind"`
			Payload map[string]any `json:"payload"`
		}
		if err := wsjson.Read(ctx, socket, &ready); err != nil {
			t.Fatal(err)
		}
		if err := wsjson.Read(ctx, socket, &snapshot); err != nil {
			t.Fatal(err)
		}
		cancel()
		if ready.Kind != "connection.ready" || snapshot.Kind != "maintenance.snapshot" || snapshot.Payload["active"] != true {
			t.Fatalf("ready=%+v snapshot=%+v", ready, snapshot)
		}
	}
	if calls := reader.calls.Load(); calls >= 20 {
		t.Fatalf("initial reads were not shared: %d", calls)
	}
	ctx, cancel := context.WithTimeout(context.Background(), time.Second)
	defer cancel()
	if err := stop(ctx); err != nil {
		t.Fatal(err)
	}
	for _, socket := range sockets {
		if _, _, err := socket.Read(ctx); err == nil {
			t.Fatal("active socket survived shutdown")
		}
	}
}

func TestStartRejectsInvalidConfiguration(t *testing.T) {
	if _, _, err := Start(context.Background(), &testReader{}, "not-an-origin", nil); err == nil {
		t.Fatal("accepted invalid origin")
	}
	if _, _, err := Start(context.Background(), &testReader{}, "https://example.test", []string{"bad-cidr"}); err == nil {
		t.Fatal("accepted invalid proxy")
	}
}
