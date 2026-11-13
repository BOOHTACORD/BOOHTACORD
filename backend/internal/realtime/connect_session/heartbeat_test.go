package connectsession

import (
	"context"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/coder/websocket"
	"github.com/coder/websocket/wsjson"
	"voice-platform/backend/internal/identity/authenticate_session"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
)

func TestNegotiatedAuthenticatedHeartbeat(t *testing.T) {
	t.Parallel()
	handler := NewHandler(nil, 0, time.Now, nil, nil)
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		handler.ServeHTTP(w, r.WithContext(sessionapi.WithPrincipal(r.Context(), authenticatesession.Principal{AccountID: "member"})))
	}))
	defer server.Close()
	ctx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
	defer cancel()
	socket, _, err := websocket.Dial(ctx, "ws"+strings.TrimPrefix(server.URL, "http"), &websocket.DialOptions{
		HTTPHeader: http.Header{"Origin": {server.URL}}, Subprotocols: []string{"boohtacord.heartbeat.v1"},
	})
	if err != nil {
		t.Fatal(err)
	}
	defer socket.CloseNow()
	if socket.Subprotocol() != "boohtacord.heartbeat.v1" {
		t.Fatal("heartbeat protocol not selected")
	}
	var got Event
	if err := wsjson.Read(ctx, socket, &got); err != nil || got.Kind != "connection.ready" {
		t.Fatalf("ready: %+v, %v", got, err)
	}
	if err := wsjson.Read(ctx, socket, &got); err != nil {
		t.Fatal(err)
	}
	if got.Kind != "connection.heartbeat" || got.EventID == "" || got.OccurredAt.IsZero() || len(got.Payload) != 0 {
		t.Fatalf("unexpected heartbeat envelope: %+v", got)
	}
}

func TestLegacyAuthenticatedSocketDoesNotReceiveHeartbeat(t *testing.T) {
	t.Parallel()
	handler := NewHandler(nil, 0, time.Now, nil, nil)
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		handler.ServeHTTP(w, r.WithContext(sessionapi.WithPrincipal(r.Context(), authenticatesession.Principal{AccountID: "member"})))
	}))
	defer server.Close()
	socket, _, err := websocket.Dial(context.Background(), "ws"+strings.TrimPrefix(server.URL, "http"), nil)
	if err != nil {
		t.Fatal(err)
	}
	defer socket.CloseNow()
	ctx, cancel := context.WithTimeout(context.Background(), 16*time.Second)
	defer cancel()
	var got Event
	if err := wsjson.Read(ctx, socket, &got); err != nil || got.Kind != "connection.ready" {
		t.Fatalf("ready: %+v, %v", got, err)
	}
	if err := wsjson.Read(ctx, socket, &got); err == nil {
		t.Fatalf("unexpected legacy event: %+v", got)
	}
}
